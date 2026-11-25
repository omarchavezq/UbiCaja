import 'package:flutter/material.dart';

import '../controlador.dart';
import '../modelo.dart';
import '../tema.dart';
import 'agregar.dart';

/// Pantalla 2 · Detalle y orden de sonar.
class PantallaDetalle extends StatelessWidget {
  const PantallaDetalle({super.key, required this.ctl, required this.codigo});
  final Controlador ctl;
  final String codigo;

  Caja? _caja() {
    for (final c in ctl.cajas) { if (c.codigo == codigo) return c; }
    return null;
  }

  Future<void> _eliminar(BuildContext context, Caja caja) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar ${caja.codigo}'),
        content: Text('La caja deja de aparecer en la app y la pasarela deja de vigilar la etiqueta ${caja.nombreBle}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Paleta.rojo),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      ctl.eliminarCaja(caja);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  void _aviso(BuildContext context, String texto) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctl,
        builder: (context, _) {
          final caja = _caja();
          if (caja == null) {
            return Scaffold(appBar: AppBar(), body: const Center(child: Text('La caja ya no existe')));
          }
          final s = ctl.estadoDe(caja.etiqueta);
          return Scaffold(
            appBar: AppBar(
              title: Text(caja.codigo),
              actions: [
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'editar') {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PantallaAgregar(ctl: ctl, original: caja)));
                    } else {
                      _eliminar(context, caja);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                    PopupMenuItem(value: 'eliminar', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Eliminar'))),
                  ],
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Mapa del almacén',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4B5563), fontSize: 15)),
                    const SizedBox(height: 10),
                    MapaAlmacen(seleccionado: caja.estante),
                  ]),
                ),
                const SizedBox(height: 12),
                Tarjeta(
                  child: Column(children: [
                    _Fila('Contenido', caja.contenido),
                    _Fila('Ubicación', caja.ubicacion),
                    _Fila('Etiqueta', caja.nombreBle),
                    _Fila('Señal / visto',
                        '${!s.conectada ? 'sin señal' : s.rssi == null ? 'conectada' : '${s.rssi} dBm'} · ${hace(s.visto)}'),
                  ]),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Paleta.naranja,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: .5),
                    ),
                    onPressed: () {
                      if (!ctl.sonar(caja)) {
                        _aviso(context, 'Sin conexión con el servidor MQTT');
                      } else if (!ctl.gatewayEnLinea) {
                        _aviso(context, 'La pasarela no está en línea: la orden puede no llegar');
                      }
                    },
                    child: Text(s.buscando ? 'VOLVER A SONAR' : 'HACER SONAR'),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('Estado de la búsqueda',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF4B5563))),
                ),
                const SizedBox(height: 8),
                _LineaTiempo(s: s),
                const SizedBox(height: 14),
                Center(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(180, 46),
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: Color(0xFF374151), width: 1.4),
                      foregroundColor: Paleta.texto,
                    ),
                    onPressed: s.estado == 'ALERTA' || s.buscando
                        ? () { if (!ctl.detener(caja)) _aviso(context, 'Sin conexión con el servidor MQTT'); }
                        : null,
                    child: const Text('Detener', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _Fila extends StatelessWidget {
  const _Fila(this.etiqueta, this.valor);
  final String etiqueta;
  final String valor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(etiqueta, style: const TextStyle(color: Paleta.suave, fontSize: 15))),
          Expanded(
            child: Text(valor,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Paleta.texto)),
          ),
        ]),
      );
}

enum _Paso { hecho, actual, error, pendiente }

class _LineaTiempo extends StatelessWidget {
  const _LineaTiempo({required this.s});
  final EstadoEtiqueta s;

  @override
  Widget build(BuildContext context) {
    final orden = s.ordenEnviada;
    if (orden == null) {
      final ultimo = s.estado == 'ENCONTRADA'
          ? 'Última búsqueda: caja encontrada'
          : s.estado == 'NO_ENCONTRADA' ? 'Última búsqueda: no encontrada' : 'Sin búsqueda en curso';
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Text('$ultimo. Presiona HACER SONAR para que la etiqueta parpadee y suene.',
            style: const TextStyle(color: Paleta.suave)),
      );
    }
    final ahora = DateTime.now();
    final pasos = <(_Paso, String, String)>[];
    pasos.add((_Paso.hecho, 'Orden enviada', hora(orden)));

    if (s.resultado == 'SIN_ENTREGA') {
      pasos.add((_Paso.error, 'La pasarela no encontró la etiqueta', hora(s.resultadoEn!)));
    } else {
      final sonando = s.sonando;
      pasos.add(sonando != null
          ? (_Paso.hecho, 'Etiqueta sonando', hora(sonando))
          : (_Paso.actual, 'Esperando a la etiqueta…', cronometro(ahora.difference(orden))));
      if (s.resultado == 'ENCONTRADA') {
        final seg = s.resultadoEn!.difference(orden).inSeconds;
        pasos.add((_Paso.hecho, 'Encontrada en $seg s', hora(s.resultadoEn!)));
      } else if (s.resultado == 'NO_ENCONTRADA') {
        pasos.add((_Paso.error, 'No encontrada (tiempo agotado)', hora(s.resultadoEn!)));
      } else if (sonando != null) {
        pasos.add((_Paso.actual, 'Esperando confirmación…', cronometro(ahora.difference(sonando))));
      } else {
        pasos.add((_Paso.pendiente, 'Confirmación con el pulsador', ''));
      }
    }

    return Column(children: [
      for (var i = 0; i < pasos.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 36,
              child: Column(children: [
                const SizedBox(height: 6),
                _Punto(pasos[i].$1),
                if (i < pasos.length - 1)
                  Expanded(child: Container(width: 2, color: const Color(0xFFCBD0D6))),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 16),
                child: Row(children: [
                  Expanded(
                    child: Text(pasos[i].$2,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: pasos[i].$1 == _Paso.actual ? FontWeight.w800 : FontWeight.w600,
                          color: pasos[i].$1 == _Paso.pendiente ? Paleta.suave : Paleta.texto,
                        )),
                  ),
                  Text(pasos[i].$3,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563), fontFeatures: [FontFeature.tabularFigures()])),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _Punto extends StatelessWidget {
  const _Punto(this.paso);
  final _Paso paso;
  @override
  Widget build(BuildContext context) {
    switch (paso) {
      case _Paso.hecho:
        return const CircleAvatar(radius: 11, backgroundColor: Paleta.verde);
      case _Paso.error:
        return const CircleAvatar(
            radius: 11, backgroundColor: Paleta.rojo, child: Icon(Icons.close, size: 14, color: Colors.white));
      case _Paso.actual:
        return Container(
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Paleta.naranja, width: 3)),
        );
      case _Paso.pendiente:
        return Container(
          width: 22, height: 22,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFCBD0D6), width: 2)),
        );
    }
  }
}
