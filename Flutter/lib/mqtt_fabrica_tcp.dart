import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

const bool esWeb = false;
String hostPorDefecto() => '192.168.1.100';

MqttClient crearCliente(String host, String id, int puertoTcp, int puertoWs) =>
    MqttServerClient.withPort(host, id, puertoTcp);
