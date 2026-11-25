import 'package:flutter/material.dart';

import '../controlador.dart';
import '../modelo.dart';
import '../tema.dart';
import 'agregar.dart';
import 'detalle.dart';

/// Pantalla 1 · Buscar caja.
class PantallaBuscar extends StatefulWidget {
  const PantallaBuscar({super.key, required this.ctl});
  final Controlador ctl;
  @override
  State<PantallaBuscar> createState() => _PantallaBuscarState();
}

class _PantallaBuscarState extends State<PantallaBuscar> {
  final _busqueda = TextEditingController();
  String _filtro = 'Todas';

  List<Caja> _filtradas() {
    final q = _busqueda.text.trim().toLowerCase();
    final ctl = widget.ctl;
    return ctl.cajas.where((c) {
      if (q.isNotEmpty &&
          !c.codigo.toLowerCase().contains(q) &&
          !c.contenido.toLowerCase().contains(q) &&
          !c.estante.toLowerCase().contains(q)) { return false; }
      if (_filtro.startsWith('Zona ')) return c.zona == _filtro.substring(5);
      if (_filtro == 'Sin señal') return !ctl.estadoDe(c.etiqueta).conectada;
      return true;
    }).toList();
  }

  void _abrirAgregar() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PantallaAgregar(ctl: widget.ctl)));

  @override
  Widget build(BuildContext context) {
    final ctl = widget.ctl;
    final cajas = _filtradas();
    return Scaffold(
      appBar: AppBar(
        title: const Text('UbiCaja · Buscar'),
        actions: [PildoraConexion(broker: ctl.conectado, gateway: ctl.gatewayEnLinea, conectando: ctl.conectando, alTocar: ctl.conectar)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirAgregar,
        backgroundColor: Paleta.azul,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar caja', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          TextField(
            controller: _busqueda,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 28),
              hintText: 'Código o contenido',
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in ['Todas', 'Zona A', 'Zona B', 'Zona C', 'Sin señal'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _filtro == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filtro = f),
                    selectedColor: Paleta.azul,
                    backgroundColor: const Color(0xFFE9EBEE),
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                        color: _filtro == f ? Colors.white : const Color(0xFF4B5563), fontWeight: FontWeight.w700),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          if (ctl.cajas.isEmpty)
            _Vacio(alAgregar: _abrirAgregar)
          else if (cajas.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Ninguna caja coincide con la búsqueda', style: TextStyle(color: Paleta.suave))),
            )
          else
            for (final c in cajas)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _TarjetaCaja(caja: c, ctl: ctl),
              ),
        ],
      ),
    );
  }
}

class _TarjetaCaja extends StatelessWidget {
  const _TarjetaCaja({required this.caja, required this.ctl});
  final Caja caja;
  final Controlador ctl;
  @override
  Widget build(BuildContext context) {
    final s = ctl.estadoDe(caja.etiqueta);
    return Tarjeta(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PantallaDetalle(ctl: ctl, codigo: caja.codigo))),
      child: Row(children: [
        const IconoCaja(),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(caja.codigo,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Paleta.texto)),
              ),
              ChipEstado(AspectoEstado.de(s, gatewayEnLinea: ctl.gatewayEnLinea)),
            ]),
            const SizedBox(height: 2),
            Text(caja.contenido,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, color: Color(0xFF374151))),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child: Text(caja.ubicacion, style: const TextStyle(fontSize: 13, color: Paleta.suave)),
              ),
              IndicadorSenal(rssi: s.rssi, conectada: s.conectada),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.alAgregar});
  final VoidCallback alAgregar;
  @override
  Widget build(BuildContext context) => Tarjeta(
        padding: const EdgeInsets.all(28),
        child: Column(children: [
          const IconoCaja(tamano: 72),
          const SizedBox(height: 16),
          const Text('Aún no hay cajas registradas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Paleta.texto)),
          const SizedBox(height: 6),
          const Text(
            'Registra una caja, indica su estante y vincúlala con una etiqueta UbiCaja cercana.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Paleta.suave),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: alAgregar, icon: const Icon(Icons.add), label: const Text('Agregar primera caja')),
        ]),
      );
}
