import 'package:flutter/material.dart';

import 'controlador.dart';
import 'pantallas/buscar.dart';
import 'pantallas/panel.dart';
import 'tema.dart';

void main() => runApp(const UbiCajaApp());

class UbiCajaApp extends StatefulWidget {
  const UbiCajaApp({super.key, this.iniciarConexion = true});
  final bool iniciarConexion; // las pruebas de widgets no abren la conexión MQTT
  @override
  State<UbiCajaApp> createState() => _UbiCajaAppState();
}

class _UbiCajaAppState extends State<UbiCajaApp> {
  final ctl = Controlador();
  AppLifecycleListener? _ciclo;

  @override
  void initState() {
    super.initState();
    if (widget.iniciarConexion) {
      ctl.iniciar();
      // Al volver a la app (desbloquear el iPhone o regresar a Safari) se rehace la conexión
      // para no mostrar estados viejos de una conexión que el sistema cortó en segundo plano.
      _ciclo = AppLifecycleListener(onResume: ctl.conectar);
    }
  }

  @override
  void dispose() {
    _ciclo?.dispose();
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'UbiCaja',
        debugShowCheckedModeBanner: false,
        theme: temaUbiCaja(),
        home: Inicio(ctl: ctl),
      );
}

class Inicio extends StatefulWidget {
  const Inicio({super.key, required this.ctl});
  final Controlador ctl;
  @override
  State<Inicio> createState() => _InicioState();
}

class _InicioState extends State<Inicio> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.ctl,
        builder: (context, _) => Scaffold(
          body: IndexedStack(index: _pestana, children: [
            PantallaBuscar(ctl: widget.ctl),
            PantallaPanel(ctl: widget.ctl),
          ]),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _pestana,
            backgroundColor: Colors.white,
            indicatorColor: Paleta.azul.withValues(alpha: .14),
            onDestinationSelected: (i) => setState(() => _pestana = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Panel'),
            ],
          ),
        ),
      );
}
