import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';

const bool esWeb = true;
// La página se sirve desde la laptop que también corre Mosquitto,
// así que el broker está en el mismo host que abrió el navegador.
String hostPorDefecto() => Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;

// host puede ser solo un nombre/IP (se usa ws://) o una URL completa,
// por ejemplo wss://broker.hivemq.com/mqtt para un broker en la nube.
MqttClient crearCliente(String host, String id, int puertoTcp, int puertoWs) =>
    MqttBrowserClient.withPort(host.startsWith('ws') ? host : 'ws://$host', id, puertoWs);
