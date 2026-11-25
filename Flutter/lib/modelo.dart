import 'dart:convert';

/// Caja registrada en el almacén y la etiqueta BLE que lleva pegada.
class Caja {
  Caja({
    required this.codigo,
    required this.contenido,
    required this.estante,
    required this.nivel,
    required this.etiqueta,
  });

  String codigo;    // CJ-0142
  String contenido; // Repuestos de bombas
  String estante;   // B-3 (columna A–C, fila 1–4)
  int nivel;        // 1–4
  String etiqueta;  // ID de la etiqueta: "A" -> anuncia como UBICAJA_A

  String get zona => estante.isEmpty ? '' : estante[0];
  String get ubicacion => 'Estante $estante · Nivel $nivel';
  String get nombreBle => 'UBICAJA_$etiqueta';

  Map<String, dynamic> aJson() => {
        'codigo': codigo,
        'contenido': contenido,
        'estante': estante,
        'nivel': nivel,
        'etiqueta': etiqueta,
      };

  factory Caja.deJson(Map<String, dynamic> j) => Caja(
        codigo: '${j['codigo'] ?? ''}',
        contenido: '${j['contenido'] ?? ''}',
        estante: '${j['estante'] ?? 'A-1'}',
        nivel: (j['nivel'] as num?)?.toInt() ?? 1,
        etiqueta: '${j['etiqueta'] ?? ''}',
      );

  static String listaAJson(List<Caja> cajas) =>
      jsonEncode(cajas.map((c) => c.aJson()).toList());

  static List<Caja> listaDeJson(String texto) {
    final datos = jsonDecode(texto);
    if (datos is! List) return [];
    return datos.whereType<Map>().map((m) => Caja.deJson(Map<String, dynamic>.from(m))).toList();
  }
}

/// Estado en vivo de una etiqueta, según lo que publica la pasarela.
class EstadoEtiqueta {
  String estado = 'SIN DATOS'; // REPOSO | ALERTA | ENCONTRADA | NO_ENCONTRADA
  String enlace = '';          // BLE_CONECTADA | BLE_PERDIDA
  int? rssi;
  DateTime? visto;             // último mensaje recibido de la etiqueta
  String? entrega;             // GATT_OK | NO_ENCONTRADA (última orden)

  // Línea de tiempo de la búsqueda en curso.
  DateTime? ordenEnviada;
  DateTime? sonando;
  DateTime? resultadoEn;
  String? resultado;           // ENCONTRADA | NO_ENCONTRADA | SIN_ENTREGA

  bool get conectada => enlace == 'BLE_CONECTADA';
  bool get buscando => ordenEnviada != null && resultado == null;

  void nuevaBusqueda(DateTime ahora) {
    ordenEnviada = ahora;
    sonando = null;
    resultadoEn = null;
    resultado = null;
    entrega = null;
  }
}

enum TipoEvento { orden, encontrada, noEncontrada, sinSenal, alta, baja }

class Evento {
  Evento(this.fecha, this.codigo, this.tipo, [this.segundos]);
  final DateTime fecha;
  final String codigo;
  final TipoEvento tipo;
  final int? segundos;

  Map<String, dynamic> aJson() =>
      {'f': fecha.millisecondsSinceEpoch, 'c': codigo, 't': tipo.name, 's': segundos};

  factory Evento.deJson(Map<String, dynamic> j) => Evento(
        DateTime.fromMillisecondsSinceEpoch((j['f'] as num).toInt()),
        '${j['c']}',
        TipoEvento.values.firstWhere((t) => t.name == j['t'], orElse: () => TipoEvento.orden),
        (j['s'] as num?)?.toInt(),
      );
}
