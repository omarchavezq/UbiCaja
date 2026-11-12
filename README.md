# UbiCaja — código fuente y recursos

Sistema de identificación de cajas: una aplicación Flutter, un gateway ESP32-C3 Wi-Fi/MQTT y dos etiquetas ESP32-C3 BLE.

## Carpetas
- `Firmware/Etiqueta_ESP32C3/`: servicio GATT, máquina de Moore (4 estados), GPIO para LED, buzzer y pulsador.
- `Firmware/Gateway_ESP32C3/`: recepción MQTT, BLE GATT, lectura y publicación de estados.
- `Flutter/`: app móvil con cliente MQTT, catálogo de cajas e historial de sesión.
- `Wokwi/`: simulación digital de LED/buzzer/botón y cuatro estados.
- `MachineLearning/`: dataset sintético RSSI, entrenamiento MLP y gráficos.
- `Protocolo/`: matriz de 27 corridas y formatos CSV para latencia, RSSI y consumo.

### Temas MQTT

- `ubicaja/comando/A`, `/B` → `SONAR` / `DETENER`
- `ubicaja/etiqueta/{id}/entrega` → `GATT_OK` / `NO_ENCONTRADA`
- `ubicaja/etiqueta/{id}/estado` → `REPOSO` / `ALERTA` / `ENCONTRADA` / `NO_ENCONTRADA`

La configuración privada de Wi-Fi y broker se carga desde `secrets.h`, que no debe publicarse.
