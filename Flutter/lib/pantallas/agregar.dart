import 'package:flutter/material.dart';

import '../controlador.dart';
import '../modelo.dart';
import '../tema.dart';

/// Alta y edición de una caja: datos, ubicación en el almacén y etiqueta BLE vinculada.
class PantallaAgregar extends StatefulWidget {
  const PantallaAgregar({super.key, required this.ctl, this.original});
  final Controlador ctl;
  final Caja? original;
  @override
  State<PantallaAgregar> createState() => _PantallaAgregarState();
}

class _PantallaAgregarState extends State<PantallaAgregar> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _codigo;
  late final TextEditingController _contenido;
  late final TextEditingController _etiqueta;
  late String _estante;
  late int _nivel;

  Controlador get ctl => widget.ctl;
  bool get _editando => widget.original != null;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _codigo = TextEditingController(text: o?.codigo ?? ctl.siguienteCodigo());
    _contenido = TextEditingController(text: o?.contenido ?? '');
    _etiqueta = TextEditingController(text: o?.etiqueta ?? '');
    _estante = o?.estante ?? 'A-1';
    _nivel = o?.nivel ?? 1;
    if (!_editando && ctl.conectado) WidgetsBinding.instance.addPostFrameCallback((_) => ctl.escanear());
  }

  /// Etiquetas ya vinculadas a otras cajas.
  Set<String> get _enUso => ctl.cajas
      .where((c) => c != widget.original)
      .map((c) => c.etiqueta)
      .toSet();

  void _guardar() {
    if (!_form.currentState!.validate()) return;
    final caja = Caja(
      codigo: _codigo.text.trim().toUpperCase(),
      contenido: _contenido.text.trim(),
      estante: _estante,
      nivel: _nivel,
      etiqueta: _etiqueta.text.trim().toUpperCase().replaceFirst('UBICAJA_', ''),
    );
    ctl.guardarCaja(caja, original: widget.original);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_editando ? '${caja.codigo} actualizada' : '${caja.codigo} registrada con ${caja.nombreBle}'),
    ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ctl,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: Text(_editando ? 'Editar ${widget.original!.codigo}' : 'Agregar caja')),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Paleta.azul,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  onPressed: _guardar,
                  child: Text(_editando ? 'GUARDAR CAMBIOS' : 'REGISTRAR CAJA'),
                ),
              ),
            ),
          ),
          body: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _Seccion('1 · Datos de la caja'),
                Tarjeta(
                  child: Column(children: [
                    TextFormField(
                      controller: _codigo,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Código', hintText: 'CJ-0001', prefixIcon: Icon(Icons.qr_code_2)),
                      validator: (v) {
                        final t = (v ?? '').trim().toUpperCase();
                        if (t.isEmpty) return 'Ingresa un código';
                        if (ctl.cajas.any((c) => c != widget.original && c.codigo == t)) return 'Ya existe una caja con ese código';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contenido,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Contenido', hintText: 'Repuestos de bombas', prefixIcon: Icon(Icons.inventory_2_outlined)),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Describe el contenido' : null,
                    ),
                  ]),
                ),
                _Seccion('2 · Ubicación en el almacén'),
                Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Toca el estante donde se guarda la caja',
                        style: TextStyle(color: Paleta.suave)),
                    const SizedBox(height: 10),
                    MapaAlmacen(
                      seleccionado: _estante,
                      ocupados: ctl.cajas.where((c) => c != widget.original).map((c) => c.estante).toSet(),
                      alElegir: (e) => setState(() => _estante = e),
                    ),
                    const SizedBox(height: 14),
                    Row(children: [
                      const Text('Nivel', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SegmentedButton<int>(
                          segments: [for (var n = 1; n <= 4; n++) ButtonSegment(value: n, label: Text('$n'))],
                          selected: {_nivel},
                          showSelectedIcon: false,
                          onSelectionChanged: (v) => setState(() => _nivel = v.first),
                        ),
                      ),
                    ]),
                  ]),
                ),
                _Seccion('3 · Etiqueta UbiCaja'),
                Tarjeta(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Expanded(
                        child: Text('Etiquetas cercanas a la pasarela',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      TextButton.icon(
                        onPressed: ctl.escaneando || !ctl.conectado ? null : ctl.escanear,
                        icon: ctl.escaneando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.bluetooth_searching),
                        label: Text(ctl.escaneando ? 'Buscando…' : 'Buscar'),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    _ListaDescubiertas(
                      ctl: ctl,
                      seleccionada: _etiqueta.text.trim().toUpperCase(),
                      enUso: _enUso,
                      alElegir: (id) => setState(() => _etiqueta.text = id),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _etiqueta,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'ID de la etiqueta',
                        hintText: 'A',
                        prefixText: 'UBICAJA_',
                        prefixIcon: Icon(Icons.sell_outlined),
                        helperText: 'Es el TAG_ID con el que se programó la etiqueta',
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim().toUpperCase().replaceFirst('UBICAJA_', '');
                        if (t.isEmpty) return 'Elige o escribe la etiqueta';
                        if (!RegExp(r'^[A-Z0-9]{1,12}$').hasMatch(t)) return 'Solo letras y números (máx. 12)';
                        if (_enUso.contains(t)) return 'Esa etiqueta ya está vinculada a otra caja';
                        return null;
                      },
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF374151))),
      );
}

class _ListaDescubiertas extends StatelessWidget {
  const _ListaDescubiertas({required this.ctl, required this.seleccionada, required this.enUso, required this.alElegir});
  final Controlador ctl;
  final String seleccionada;
  final Set<String> enUso;
  final ValueChanged<String> alElegir;

  @override
  Widget build(BuildContext context) {
    final d = ctl.descubiertas;
    if (!ctl.conectado) {
      return const Text('Sin conexión con el servidor: escribe el ID manualmente.', style: TextStyle(color: Paleta.suave));
    }
    if (d == null) {
      return Text(ctl.escaneando ? 'La pasarela está escaneando por Bluetooth…' : 'Pulsa Buscar para escanear.',
          style: const TextStyle(color: Paleta.suave));
    }
    if (d.isEmpty) {
      return Text(
          ctl.gatewayEnLinea
              ? 'No se encontraron etiquetas. Verifica que estén encendidas y cerca de la pasarela.'
              : 'La pasarela no está en línea.',
          style: const TextStyle(color: Paleta.suave));
    }
    final ids = d.keys.toList()..sort((a, b) => d[b]!.compareTo(d[a]!));
    return Column(children: [
      for (final id in ids)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Material(
            color: seleccionada == id ? Paleta.azul.withValues(alpha: .08) : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(12),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: seleccionada == id ? Paleta.azul : Paleta.borde),
              ),
              enabled: !enUso.contains(id),
              leading: const Icon(Icons.sensors, color: Paleta.azul),
              title: Text('UBICAJA_$id', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(enUso.contains(id) ? 'Vinculada a otra caja' : 'Disponible'),
              trailing: IndicadorSenal(rssi: d[id], conectada: true),
              onTap: () => alElegir(id),
            ),
          ),
        ),
    ]);
  }
}
