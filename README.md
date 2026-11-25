# UbiCaja — código fuente y recursos

Sistema de identificación de cajas: una aplicación Flutter, un gateway ESP32-C3 Wi-Fi/MQTT y dos etiquetas ESP32-C3 BLE.

## Carpetas
- `Firmware/Etiqueta_ESP32C3/`: servicio GATT con notificación, máquina de Moore (4 estados), GPIO para LED, buzzer y pulsador.
- `Firmware/Gateway_ESP32C3/`: recepción MQTT, conexión BLE persistente, escritura GATT y estados por notificación.
- `Flutter/`: app con cliente MQTT (TCP en móvil/escritorio, WebSocket en web), catálogo de cajas e historial de sesión.
- `Demo/`: configuración de Mosquitto, script de arranque y guía de la demo.
- `Wokwi/`: simulación digital de LED/buzzer/botón y cuatro estados.
- `MachineLearning/`: dataset sintético RSSI, entrenamiento MLP y gráficos.
- `Protocolo/`: matriz de 27 corridas y formatos CSV para latencia, RSSI y consumo.

### Temas MQTT

`RAIZ` es la raíz de los tópicos (`MQTT_RAIZ`): `ubicaja` en local o una raíz única en el broker público.

- `RAIZ/registro` → JSON con las cajas registradas (retenido; lo publica la app)
- `RAIZ/gateway/etiquetas` → `A,B` etiquetas que vigila la pasarela (retenido; lo publica la app)
- `RAIZ/gateway/escanear` → pide un escaneo BLE; respuesta en `RAIZ/gateway/descubiertas` (`A:-58,B:-71`)
- `RAIZ/gateway/estado` → `CONECTADO` / `DESCONECTADO` (testamento MQTT)
- `RAIZ/comando/{id}` → `SONAR` / `DETENER`
- `RAIZ/etiqueta/{id}/estado` → `REPOSO` / `ALERTA` / `ENCONTRADA` / `NO_ENCONTRADA`
- `RAIZ/etiqueta/{id}/entrega` → `GATT_OK` / `NO_ENCONTRADA`
- `RAIZ/etiqueta/{id}/enlace` → `BLE_CONECTADA` / `BLE_PERDIDA`
- `RAIZ/etiqueta/{id}/rssi` → RSSI en dBm cada 5 s

### Pines de la etiqueta (PCB)

GPIO3 LED · GPIO4 pulsador (MUTE, activo en bajo) · GPIO5 buzzer pasivo vía MOSFET AO3400 (alimentado desde VBAT, excitado por PWM con melodías).

### Demo

Ver `Demo/GUIA_DEMO.md` (1 gateway + 1 etiqueta, iPhone + laptop).
