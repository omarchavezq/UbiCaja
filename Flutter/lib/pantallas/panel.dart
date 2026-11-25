import 'package:flutter/material.dart';

import '../controlador.dart';
import '../modelo.dart';
import '../tema.dart';

/// Pantalla 3 · Panel del almacén e historial.
class PantallaPanel extends StatelessWidget {
  const PantallaPanel({super.key, required this.ctl});
  final Controlador ctl;

  @override
  Widget build(BuildContext context) {
    final medio = ctl.tiempoMedio;
    final eventos = ctl.eventos.where((e) => e.tipo != TipoEvento.orden).take(25).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del almacén'),
        actions: [PildoraConexion(broker: ctl.conectado, gateway: ctl.gatewayEnLinea, conectando: ctl.conectando, alTocar: ctl.conectar)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(children: [
            Expanded(child: _Kpi(valor: medio == null ? '—' : '$medio s', texto: 'tiempo medio\nde búsqueda')),
            const SizedBox(width: 10),
            Expanded(child: _Kpi(valor: '${ctl.encontradasHoy} / ${ctl.busquedasHoy}', texto: 'encontradas\nhoy')),
            const SizedBox(width: 10),
            Expanded(
              child: _Kpi(
                valor: '${ctl.sinSenal}',
                texto: 'etiquetas\nsin señal',
                color: ctl.sinSenal > 0 ? Paleta.rojo : Paleta.texto,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Tarjeta(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Búsquedas por día (semana)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF4B5563))),
              const SizedBox(height: 16),
              _Barras(valores: ctl.busquedasSemana),
            ]),
          ),
          const SizedBox(height: 12),
          _EstadoSistema(ctl: ctl),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 18, 4, 8),
            child: Text('Últimos eventos',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF4B5563))),
          ),
          if (eventos.isEmpty)
            const Tarjeta(child: Text('Los eventos aparecerán al buscar cajas.', style: TextStyle(color: Paleta.suave)))
          else
            for (final e in eventos)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: _FilaEvento(e: e, ctl: ctl)),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.valor, required this.texto, this.color = Paleta.texto});
  final String valor;
  final String texto;
  final Color color;
  @override
  Widget build(BuildContext context) => Tarjeta(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(children: [
          FittedBox(
            child: Text(valor, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(height: 6),
          Text(texto, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.3)),
        ]),
      );
}

class _Barras extends StatelessWidget {
  const _Barras({required this.valores});
  final List<int> valores;
  static const _dias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  @override
  Widget build(BuildContext context) {
    final max = valores.fold<int>(0, (a, b) => b > a ? b : a);
    final hoy = DateTime.now().weekday; // 1 = lunes
    return SizedBox(
      height: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (valores[i] > 0)
                Text('${valores[i]}', style: const TextStyle(fontSize: 12, color: Paleta.suave, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 24,
                height: max == 0 ? 3 : 3 + 100 * valores[i] / max,
                decoration: BoxDecoration(
                  color: i == 6 ? Paleta.azul : Paleta.azul.withValues(alpha: .55),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
              Container(height: 1.5, color: const Color(0xFF9AA1AB)),
              const SizedBox(height: 6),
              Text(_dias[(hoy - 7 + i) % 7],
                  style: TextStyle(
                      color: i == 6 ? Paleta.texto : Paleta.suave, fontWeight: i == 6 ? FontWeight.w800 : FontWeight.w500)),
            ]),
          ),
      ]),
    );
  }
}

class _EstadoSistema extends StatelessWidget {
  const _EstadoSistema({required this.ctl});
  final Controlador ctl;
  @override
  Widget build(BuildContext context) {
    Widget fila(IconData icono, String titulo, String detalle, bool ok) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(icono, color: ok ? Paleta.verde : Paleta.rojo, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(detalle, style: const TextStyle(color: Paleta.suave, fontSize: 13)),
          ]),
        );
    final conectadas = ctl.cajas.where((c) => ctl.estadoDe(c.etiqueta).conectada).length;
    return Tarjeta(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Estado del sistema',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF4B5563))),
        const SizedBox(height: 6),
        fila(Icons.cloud_outlined, 'Servidor MQTT', ctl.conectado ? 'conectado' : 'sin conexión', ctl.conectado),
        fila(Icons.router_outlined, 'Pasarela ESP32-C3', ctl.gatewayEnLinea ? 'en línea' : 'offline', ctl.gatewayEnLinea),
        fila(Icons.sensors, 'Etiquetas BLE', '$conectadas de ${ctl.cajas.length} conectadas',
            ctl.cajas.isNotEmpty && conectadas == ctl.cajas.length),
      ]),
    );
  }
}

class _FilaEvento extends StatelessWidget {
  const _FilaEvento({required this.e, required this.ctl});
  final Evento e;
  final Controlador ctl;
  @override
  Widget build(BuildContext context) {
    final (color, texto) = switch (e.tipo) {
      TipoEvento.encontrada => (Paleta.verde, '${e.codigo} encontrada${e.segundos == null ? '' : ' en ${e.segundos} s'}'),
      TipoEvento.noEncontrada => (Paleta.rojo, '${e.codigo} no encontrada${e.segundos == null ? '' : ' (${e.segundos} s)'}'),
      TipoEvento.sinSenal => (Paleta.ambar, '${e.codigo} sin señal: revisar'),
      TipoEvento.alta => (Paleta.azul, '${e.codigo} registrada'),
      TipoEvento.baja => (Paleta.suave, '${e.codigo} eliminada'),
      TipoEvento.orden => (Paleta.naranja, '${e.codigo}: orden de sonar'),
    };
    final hoy = DateTime.now();
    final mismoDia = e.fecha.year == hoy.year && e.fecha.month == hoy.month && e.fecha.day == hoy.day;
    final cuando = mismoDia ? horaCorta(e.fecha) : '${e.fecha.day}/${e.fecha.month} ${horaCorta(e.fecha)}';
    String? lugar;
    for (final c in ctl.cajas) { if (c.codigo == e.codigo) lugar = c.ubicacion; }
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(texto, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(lugar == null ? cuando : '$cuando · $lugar', style: const TextStyle(color: Paleta.suave, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}
