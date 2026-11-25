import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'modelo.dart';
import 'mqtt_fabrica.dart';

/// Lógica de la app: conexión MQTT, registro de cajas, búsquedas e historial.
///
/// Tópicos (RAIZ = MQTT_RAIZ):
///   RAIZ/registro                 JSON con las cajas (retenido, compartido entre teléfonos)
///   RAIZ/gateway/etiquetas        "A,B" etiquetas que la pasarela debe vigilar (retenido)
///   RAIZ/gateway/escanear         pide un escaneo BLE
///   RAIZ/gateway/descubiertas     "A:-58,B:-71" respuesta del escaneo
///   RAIZ/gateway/estado           CONECTADO | DESCONECTADO
///   RAIZ/comando/ID               SONAR | DETENER
///   RAIZ/etiqueta/ID/estado|enlace|entrega|rssi
class Controlador extends ChangeNotifier {
  static const hostConfigurado = String.fromEnvironment('MQTT_HOST');
  static final host = hostConfigurado.isEmpty ? hostPorDefecto() : hostConfigurado;
  static const puerto = int.fromEnvironment('MQTT_PORT', defaultValue: 1883);
  static const puertoWs = int.fromEnvironment('MQTT_WS_PORT', defaultValue: 9001);
  static const raiz = String.fromEnvironment('MQTT_RAIZ', defaultValue: 'ubicaja');
  static const usuario = String.fromEnvironment('MQTT_USER');
  static const clave = String.fromEnvironment('MQTT_PASS');

  MqttClient? _cliente;
  StreamSubscription? _sub;
  Timer? _reloj;
  SharedPreferences? _prefs;

  bool conectado = false;
  bool conectando = false;
  String gateway = 'SIN DATOS';
  final List<Caja> cajas = [];
  final Map<String, EstadoEtiqueta> etiquetas = {};
  final List<Evento> eventos = [];

  // Descubrimiento de etiquetas cercanas (pantalla Agregar).
  bool escaneando = false;
  Map<String, int>? descubiertas;
  bool _registroRecibido = false;

  String get servidor => esWeb ? '$host:$puertoWs' : '$host:$puerto';
  bool get gatewayEnLinea => gateway == 'CONECTADO';

  EstadoEtiqueta estadoDe(String idEtiqueta) =>
      etiquetas.putIfAbsent(idEtiqueta, () => EstadoEtiqueta());

  Future<void> iniciar() async {
    _prefs = await SharedPreferences.getInstance();
    final guardadas = _prefs!.getString('cajas');
    if (guardadas != null) {
      try { cajas..clear()..addAll(Caja.listaDeJson(guardadas)); } catch (_) {}
    }
    final ev = _prefs!.getString('eventos');
    if (ev != null) {
      try {
        eventos..clear()..addAll((jsonDecode(ev) as List)
            .map((e) => Evento.deJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
    // Reloj para los contadores "hace X s" y el cronómetro de búsqueda.
    // Si el reloj se saltó varios segundos, la página estuvo dormida (iPhone bloqueado o Safari
    // en segundo plano) y la conexión pudo morir sin aviso: se rehace para traer el estado actual.
    var ultimoTic = DateTime.now();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      final ahora = DateTime.now();
      if (ahora.difference(ultimoTic) > const Duration(seconds: 5)) conectar();
      ultimoTic = ahora;
      notifyListeners();
    });
    notifyListeners();
    await conectar();
  }

  Future<void> conectar() async {
    if (conectando) return;
    conectando = true;
    notifyListeners();
    await _sub?.cancel();
    final anterior = _cliente;
    _cliente = null; // así el aviso de desconexión del cliente anterior se ignora
    try { anterior?.disconnect(); } catch (_) {}
    final c = crearCliente(host, 'ubicaja_app_${DateTime.now().millisecondsSinceEpoch}', puerto, puertoWs);
    c.logging(on: false);
    // Safari en iPhone corta el WebSocket sin avisar al bloquear la pantalla o cambiar de app.
    // Con ping cada 10 s y corte si no responde en 5 s, la conexión muerta se detecta y se rehace.
    c.keepAlivePeriod = 10;
    c.disconnectOnNoResponsePeriod = 5;
    c.setProtocolV311(); // los brokers en la nube no aceptan MQTT 3.1
    c.onDisconnected = () {
      if (_cliente != c) return;
      conectado = false;
      notifyListeners();
      // Reconexión completa: vuelve a suscribirse y recibe los estados retenidos actuales.
      Future.delayed(const Duration(seconds: 2), () { if (_cliente == c && !conectado) conectar(); });
    };
    c.connectionMessage = MqttConnectMessage().withClientIdentifier(c.clientIdentifier).startClean();
    try {
      if (usuario.isEmpty) { await c.connect(); } else { await c.connect(usuario, clave); }
    } catch (_) {}
    conectando = false;
    if (c.connectionStatus?.state != MqttConnectionState.connected) {
      try { c.disconnect(); } catch (_) {}
      conectado = false;
      notifyListeners();
      // Reintento automático (sin señal, broker caído, etc.).
      Future.delayed(const Duration(seconds: 4), () { if (!conectado) conectar(); });
      return;
    }
    _cliente = c;
    conectado = true;
    // Escuchar antes de suscribirse: los mensajes retenidos llegan apenas se acepta la suscripción.
    _sub = c.updates?.listen(_alRecibir);
    for (final t in ['registro', 'gateway/estado', 'gateway/descubiertas', 'etiqueta/+/+']) {
      c.subscribe('$raiz/$t', MqttQos.atLeastOnce);
    }
    notifyListeners();
    // Si el broker no tiene registro retenido, se publica el que está guardado en el teléfono.
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!_registroRecibido && cajas.isNotEmpty) _publicarRegistro();
    });
  }

  void _alRecibir(List<MqttReceivedMessage<MqttMessage>> mensajes) {
    for (final m in mensajes) {
      final pub = m.payload as MqttPublishMessage;
      final texto = MqttPublishPayload.bytesToStringAsString(pub.payload.message);
      final retenido = pub.header?.retain ?? false;
      final topico = m.topic.substring(raiz.length + 1);
      final partes = topico.split('/');
      final ahora = DateTime.now();

      if (topico == 'registro') {
        _registroRecibido = true;
        if (texto.isEmpty) continue;
        try {
          final lista = Caja.listaDeJson(texto);
          cajas..clear()..addAll(lista);
          _guardarCajas();
        } catch (_) {}
      } else if (topico == 'gateway/estado') {
        gateway = texto;
      } else if (topico == 'gateway/descubiertas') {
        escaneando = false;
        final mapa = <String, int>{};
        if (texto != 'NINGUNA') {
          for (final par in texto.split(',')) {
            final kv = par.split(':');
            if (kv.length == 2 && kv[0].isNotEmpty) mapa[kv[0]] = int.tryParse(kv[1]) ?? -100;
          }
        }
        descubiertas = mapa;
      } else if (partes.length == 3 && partes[0] == 'etiqueta') {
        final id = partes[1];
        final s = estadoDe(id);
        if (texto.isEmpty) continue; // retenido borrado
        if (!retenido) s.visto = ahora;
        switch (partes[2]) {
          case 'estado':
            final anterior = s.estado;
            s.estado = texto;
            if (retenido) break;
            final caja = _cajaDeEtiqueta(id);
            if (texto == 'ALERTA') {
              s.ordenEnviada ??= ahora;
              s.sonando ??= ahora;
            } else if ((texto == 'ENCONTRADA' || texto == 'NO_ENCONTRADA') && anterior == 'ALERTA') {
              s.resultado = texto;
              s.resultadoEn = ahora;
              final inicio = s.ordenEnviada ?? s.sonando;
              final seg = inicio == null ? null : ahora.difference(inicio).inSeconds;
              if (caja != null) {
                _registrar(Evento(ahora, caja.codigo,
                    texto == 'ENCONTRADA' ? TipoEvento.encontrada : TipoEvento.noEncontrada, seg));
              }
            } else if (texto == 'REPOSO' && s.buscando) {
              // Detenida desde la app antes de confirmar.
              s.ordenEnviada = null;
              s.sonando = null;
            }
          case 'enlace':
            final antes = s.enlace;
            s.enlace = texto;
            final caja = _cajaDeEtiqueta(id);
            if (!retenido && antes == 'BLE_CONECTADA' && texto == 'BLE_PERDIDA' && caja != null) {
              _registrar(Evento(ahora, caja.codigo, TipoEvento.sinSenal));
            }
          case 'entrega':
            s.entrega = texto;
            if (texto == 'NO_ENCONTRADA' && s.buscando) {
              s.resultado = 'SIN_ENTREGA';
              s.resultadoEn = ahora;
            }
          case 'rssi':
            s.rssi = int.tryParse(texto);
        }
      }
    }
    notifyListeners();
  }

  Caja? _cajaDeEtiqueta(String id) {
    for (final c in cajas) { if (c.etiqueta == id) return c; }
    return null;
  }

  void _publicar(String topico, String texto, {bool retener = false}) {
    final c = _cliente;
    if (c == null || c.connectionStatus?.state != MqttConnectionState.connected) return;
    final b = MqttClientPayloadBuilder()..addUTF8String(texto);
    c.publishMessage('$raiz/$topico', MqttQos.atLeastOnce, b.payload!, retain: retener);
  }

  void _publicarRegistro() {
    _publicar('registro', Caja.listaAJson(cajas), retener: true);
    final ids = cajas.map((c) => c.etiqueta).where((e) => e.isNotEmpty).toSet().join(',');
    _publicar('gateway/etiquetas', ids, retener: true);
  }

  void _guardarCajas() => _prefs?.setString('cajas', Caja.listaAJson(cajas));

  void _registrar(Evento e) {
    eventos.insert(0, e);
    if (eventos.length > 300) eventos.removeRange(300, eventos.length);
    _prefs?.setString('eventos', jsonEncode(eventos.map((e) => e.aJson()).toList()));
  }

  // ---------- Acciones ----------

  bool sonar(Caja caja) {
    if (!conectado) return false;
    estadoDe(caja.etiqueta).nuevaBusqueda(DateTime.now());
    _registrar(Evento(DateTime.now(), caja.codigo, TipoEvento.orden));
    _publicar('comando/${caja.etiqueta}', 'SONAR');
    notifyListeners();
    return true;
  }

  bool detener(Caja caja) {
    if (!conectado) return false;
    _publicar('comando/${caja.etiqueta}', 'DETENER');
    final s = estadoDe(caja.etiqueta);
    s.ordenEnviada = null;
    s.sonando = null;
    s.resultado = null;
    notifyListeners();
    return true;
  }

  void escanear() {
    descubiertas = null;
    escaneando = true;
    notifyListeners();
    _publicar('gateway/escanear', '1');
    // Si la pasarela no responde, se libera el botón.
    Future.delayed(const Duration(seconds: 10), () {
      if (escaneando) { escaneando = false; descubiertas ??= {}; notifyListeners(); }
    });
  }

  void guardarCaja(Caja caja, {Caja? original}) {
    if (original != null) {
      final i = cajas.indexOf(original);
      if (i >= 0) {
        cajas[i] = caja;
      } else {
        cajas.add(caja);
      }
    } else {
      cajas.add(caja);
      _registrar(Evento(DateTime.now(), caja.codigo, TipoEvento.alta));
    }
    _guardarCajas();
    _publicarRegistro();
    notifyListeners();
  }

  void eliminarCaja(Caja caja) {
    cajas.remove(caja);
    _registrar(Evento(DateTime.now(), caja.codigo, TipoEvento.baja));
    _guardarCajas();
    _publicarRegistro();
    notifyListeners();
  }

  String siguienteCodigo() {
    var max = 0;
    for (final c in cajas) {
      final n = int.tryParse(c.codigo.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      if (n > max) max = n;
    }
    return 'CJ-${(max + 1).toString().padLeft(4, '0')}';
  }

  // ---------- Indicadores del panel ----------

  bool _esHoy(DateTime f) {
    final h = DateTime.now();
    return f.year == h.year && f.month == h.month && f.day == h.day;
  }

  int? get tiempoMedio {
    final t = eventos.where((e) => e.tipo == TipoEvento.encontrada && e.segundos != null).map((e) => e.segundos!).toList();
    if (t.isEmpty) return null;
    return (t.reduce((a, b) => a + b) / t.length).round();
  }

  int get encontradasHoy => eventos.where((e) => e.tipo == TipoEvento.encontrada && _esHoy(e.fecha)).length;
  int get busquedasHoy => eventos.where((e) => e.tipo == TipoEvento.orden && _esHoy(e.fecha)).length;
  int get sinSenal => cajas.where((c) => !estadoDe(c.etiqueta).conectada).length;

  /// Búsquedas de los últimos 7 días (índice 6 = hoy).
  List<int> get busquedasSemana {
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    final r = List.filled(7, 0);
    for (final e in eventos.where((e) => e.tipo == TipoEvento.orden)) {
      final d = DateTime(e.fecha.year, e.fecha.month, e.fecha.day);
      final dias = base.difference(d).inDays;
      if (dias >= 0 && dias < 7) r[6 - dias]++;
    }
    return r;
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _sub?.cancel();
    _cliente?.disconnect();
    super.dispose();
  }
}
