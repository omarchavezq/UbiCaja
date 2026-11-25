// Elige el cliente MQTT según la plataforma:
// - Android/iOS/Windows: TCP directo (puerto 1883).
// - Web (Safari del iPhone, Chrome): WebSocket (puerto 9001 de Mosquitto).
export 'mqtt_fabrica_tcp.dart' if (dart.library.js_interop) 'mqtt_fabrica_web.dart';
