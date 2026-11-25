import 'package:flutter/material.dart';

import 'modelo.dart';

/// Colores tomados del prototipo de interfaz de la documentación (UbiCaja_interfaz.png).
class Paleta {
  static const azul = Color(0xFF2B78D6);
  static const naranja = Color(0xFFE8693A);
  static const fondo = Color(0xFFF4F5F7);
  static const tarjeta = Colors.white;
  static const borde = Color(0xFFE2E5EA);
  static const texto = Color(0xFF1F2328);
  static const suave = Color(0xFF6B7280);
  static const verde = Color(0xFF1E8E3E);
  static const rojo = Color(0xFFD93B3B);
  static const ambar = Color(0xFFE5A100);
  static const carton = Color(0xFFEAD7B9);
  static const cartonBorde = Color(0xFF9C7A52);
}

ThemeData temaUbiCaja() {
  final base = ColorScheme.fromSeed(seedColor: Paleta.azul, primary: Paleta.azul, surface: Paleta.fondo);
  return ThemeData(
    useMaterial3: true,
    colorScheme: base,
    scaffoldBackgroundColor: Paleta.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Paleta.fondo,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Paleta.texto,
      elevation: 0,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Paleta.texto),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Paleta.borde)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Paleta.borde)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Paleta.azul, width: 1.6)),
    ),
  );
}

/// Contenedor blanco con borde suave, como las tarjetas del prototipo.
class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Paleta.tarjeta,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Paleta.borde),
            ),
            child: child,
          ),
        ),
      );
}

/// Ícono de caja de cartón con la etiqueta azul.
class IconoCaja extends StatelessWidget {
  const IconoCaja({super.key, this.tamano = 54});
  final double tamano;
  @override
  Widget build(BuildContext context) => Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: Paleta.carton,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Paleta.cartonBorde, width: 1.4),
        ),
        alignment: Alignment.center,
        child: Container(
          width: tamano * .42,
          height: tamano * .3,
          decoration: BoxDecoration(color: Paleta.azul, borderRadius: BorderRadius.circular(3)),
        ),
      );
}

/// Texto, color de fondo y de letra del chip de estado de una caja.
class AspectoEstado {
  const AspectoEstado(this.texto, this.fondo, this.letra);
  final String texto;
  final Color fondo;
  final Color letra;

  static AspectoEstado de(EstadoEtiqueta s, {required bool gatewayEnLinea}) {
    if (s.estado == 'ALERTA') return const AspectoEstado('Sonando', Color(0xFFFDE8DF), Color(0xFFC2541E));
    if (s.estado == 'ENCONTRADA') return const AspectoEstado('Encontrada', Color(0xFFE2F4E6), Paleta.verde);
    if (s.estado == 'NO_ENCONTRADA') return const AspectoEstado('No encontrada', Color(0xFFFBE3E3), Paleta.rojo);
    if (!gatewayEnLinea) return const AspectoEstado('Pasarela offline', Color(0xFFECEDEF), Paleta.suave);
    if (!s.conectada) return const AspectoEstado('Sin señal', Color(0xFFFFF3D3), Color(0xFF946600));
    return const AspectoEstado('En reposo', Color(0xFFECEDEF), Color(0xFF4B5563));
  }
}

class ChipEstado extends StatelessWidget {
  const ChipEstado(this.aspecto, {super.key});
  final AspectoEstado aspecto;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: aspecto.fondo, borderRadius: BorderRadius.circular(20)),
        child: Text(aspecto.texto,
            style: TextStyle(color: aspecto.letra, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}

/// Barras de señal BLE según el RSSI.
class IndicadorSenal extends StatelessWidget {
  const IndicadorSenal({super.key, required this.rssi, required this.conectada});
  final int? rssi;
  final bool conectada;
  @override
  Widget build(BuildContext context) {
    final r = rssi;
    final nivel = !conectada || r == null ? 0 : r >= -60 ? 4 : r >= -70 ? 3 : r >= -80 ? 2 : 1;
    final color = nivel >= 3 ? Paleta.verde : nivel == 2 ? Paleta.ambar : Paleta.rojo;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      for (var i = 1; i <= 4; i++)
        Container(
          width: 4,
          height: 4.0 + i * 3,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: i <= nivel ? color : const Color(0xFFD5D9DF),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      const SizedBox(width: 6),
      Text(!conectada ? 'sin señal' : r == null ? 'conectada' : '$r dBm',
          style: const TextStyle(fontSize: 13, color: Paleta.suave, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// Mapa del almacén: 3 columnas (A, B, C) × 4 estantes, con la puerta abajo.
class MapaAlmacen extends StatelessWidget {
  const MapaAlmacen({super.key, required this.seleccionado, this.alElegir, this.ocupados = const {}});
  final String seleccionado;
  final ValueChanged<String>? alElegir;
  final Set<String> ocupados;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var fila = 1; fila <= 4; fila++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              for (final col in ['A', 'B', 'C'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _Estante(
                      nombre: '$col-$fila',
                      activo: seleccionado == '$col-$fila',
                      ocupado: ocupados.contains('$col-$fila'),
                      alTocar: alElegir == null ? null : () => alElegir!('$col-$fila'),
                    ),
                  ),
                ),
            ]),
          ),
        const SizedBox(height: 4),
        const Text('Puerta ▼', style: TextStyle(color: Paleta.suave, fontSize: 13)),
      ]);
}

class _Estante extends StatelessWidget {
  const _Estante({required this.nombre, required this.activo, required this.ocupado, this.alTocar});
  final String nombre;
  final bool activo;
  final bool ocupado;
  final VoidCallback? alTocar;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: alTocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activo ? Paleta.naranja : const Color(0xFFEDEEF0),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: activo ? const Color(0xFFB8471C) : const Color(0xFFC9CDD3), width: activo ? 2 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(nombre,
                style: TextStyle(
                    color: activo ? Colors.white : Paleta.suave,
                    fontWeight: activo ? FontWeight.w800 : FontWeight.w500)),
            if (ocupado && !activo) ...[
              const SizedBox(width: 4),
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Paleta.azul, shape: BoxShape.circle)),
            ],
          ]),
        ),
      );
}

/// Indicador de conexión en la esquina superior (reemplaza al avatar del prototipo).
class PildoraConexion extends StatelessWidget {
  const PildoraConexion({super.key, required this.broker, required this.gateway, this.conectando = false, this.alTocar});
  final bool broker;
  final bool conectando;
  final bool gateway;
  final VoidCallback? alTocar;
  @override
  Widget build(BuildContext context) {
    final ok = broker && gateway;
    final color = ok ? Paleta.verde : broker ? Paleta.ambar : conectando ? Paleta.azul : Paleta.rojo;
    final texto = ok ? 'En línea' : broker ? 'Pasarela offline' : conectando ? 'Conectando…' : 'Sin conexión';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: alTocar,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
    );
  }
}

String hora(DateTime f) =>
    '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}:${f.second.toString().padLeft(2, '0')}';

String horaCorta(DateTime f) => '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';

String hace(DateTime? f) {
  if (f == null) return 'sin datos';
  final s = DateTime.now().difference(f).inSeconds;
  if (s < 60) return 'hace ${s < 0 ? 0 : s} s';
  if (s < 3600) return 'hace ${s ~/ 60} min';
  return 'hace ${s ~/ 3600} h';
}

String cronometro(Duration d) =>
    '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
