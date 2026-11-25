# Guía de la demo UbiCaja (1 gateway + 1 etiqueta)

## Modo nube (recomendado: sin laptop)

```
iPhone (hotspot 2,4 GHz + datos móviles)
  ├── Gateway ESP32-C3 ── TCP 1883 ──► broker.hivemq.com ◄── WSS 8884 ── Safari del iPhone (app en GitHub Pages)
  └── Etiqueta (PCB) ◄── BLE ── Gateway
```

- Broker público gratuito `broker.hivemq.com`. Los tópicos usan la raíz única `ubicaja_t3_mc3que` (en `secrets.h` y en la app), para que nadie más interfiera.
- `secrets.h` ya apunta a la nube; solo falta poner el nombre y la clave del hotspot.
- El gateway se alimenta con un cargador USB o una power bank, sin laptop.
- La app se abre en Safari: `https://omarchavezq.github.io/UbiCaja/`.
- Requisito: el iPhone necesita datos móviles. Si no hay señal en el aula, usar el modo local con la laptop (secciones siguientes, Opción B en `secrets.h`).
- Para recompilar la app de la nube:
  ```powershell
  $env:PUB_CACHE='F:\flutter_sdk\pub_cache'; $env:PATH="F:\flutter_sdk\flutter\bin;$env:PATH"
  cd Flutter
  flutter build web --release --no-web-resources-cdn --base-href /UbiCaja/ --dart-define=MQTT_HOST=wss://broker.hivemq.com/mqtt --dart-define=MQTT_WS_PORT=8884 --dart-define=MQTT_RAIZ=ubicaja_t3_mc3que -o F:\ubicaja_web_nube
  ```
- Para vigilar el tráfico desde cualquier PC: MQTTX conectado a `broker.hivemq.com:1883`, suscrito a `ubicaja_t3_mc3que/#`.

### La app (basada en el prototipo de interfaz de la documentación)

- **Buscar:** lista de cajas con búsqueda por código o contenido, filtros por zona y "Sin señal", estado en vivo e intensidad de señal BLE.
- **Agregar caja:** código, contenido, estante en el mapa del almacén (A-1 a C-4) y nivel. Al abrirla, la pasarela escanea por Bluetooth y muestra las etiquetas `UBICAJA_*` cercanas con su RSSI; se vincula una con un toque. También se puede editar o eliminar desde el detalle.
- **Detalle:** mapa con el estante resaltado, datos, botón HACER SONAR y línea de tiempo (orden enviada → etiqueta sonando → esperando confirmación con cronómetro → encontrada en X s).
- **Panel:** tiempo medio de búsqueda, encontradas hoy, etiquetas sin señal, búsquedas por día, estado del sistema y últimos eventos.
- El registro de cajas se guarda en el broker (retenido) y en el teléfono, así que lo ven todos los teléfonos que abran la app. La pasarela recibe la lista de etiquetas registradas y solo se conecta a esas (máx. 3).
- Para agregar otra etiqueta física: programarla con otro `TAG_ID` (por ejemplo `"B"`) y registrarla desde la app. No hay que reprogramar la pasarela.

### Guion de la demo en modo nube

1. Abrir la app: "En línea" arriba a la derecha y la lista vacía.
2. "Agregar caja" → aparece UBICAJA_A con su señal → completar CJ-0142, "Repuestos de bombas", B-3, nivel 2 → Registrar.
3. Abrir la caja → HACER SONAR → la etiqueta suena; la línea de tiempo avanza.
4. Presionar el pulsador → "Encontrada en X s".
5. Mostrar el Panel con el tiempo medio y el evento.

## Modo local (laptop como broker)

## Montaje

```
iPhone (hotspot 2,4 GHz) ── Wi-Fi ──┬── Laptop: Mosquitto 1883/9001 + página de la app :8080
                                    └── Gateway ESP32-C3 ── BLE ── Etiqueta (PCB: LED, buzzer, pulsador)
iPhone Safari ── http://IP_LAPTOP:8080 ── app Flutter web ── WebSocket 9001 ── Mosquitto
```

No hace falta Android ni Mac: la app Flutter se compila para web y se abre en Safari del iPhone.

## 1. Carga rápida sin IDE (ya instalado en F:)

Core ESP32 3.3.13, NimBLE-Arduino 2.5.2 y arduino-cli están en `F:\Arduino15_ubicaja`. Ambos firmwares ya se compilaron sin errores.

```powershell
F:\Arduino15_ubicaja\bin\arduino-cli.exe board list
powershell -ExecutionPolicy Bypass -File .\Demo\cargar_firmware.ps1 -Placa etiqueta -Puerto COM5 -Monitor
powershell -ExecutionPolicy Bypass -File .\Demo\cargar_firmware.ps1 -Placa gateway -Puerto COM6 -Monitor
```

## 1b. Alternativa: Arduino IDE

1. Gestor de tarjetas: instalar **esp32 de Espressif, versión 3.x**.
2. Gestor de librerías: instalar **NimBLE-Arduino de h2zero, versión 2.x** (el código no compila con la 1.x). PubSubClient ya está instalado.
3. Placa: **ESP32C3 Dev Module** (o "Nologo ESP32C3 Super Mini"). Activar **USB CDC On Boot: Enabled** para ver el monitor serie.
4. Si la placa no entra en modo de carga: mantener BOOT, pulsar RESET, soltar BOOT.

## 2. Etiqueta (placa PCB)

- Abrir `Firmware/Etiqueta_ESP32C3`, `TAG_ID "A"`, cargar.
- Monitor serie a 115200: debe decir `UBICAJA_A anunciando por BLE`.
- **El buzzer es pasivo y se alimenta de VBAT**: el firmware lo excita con PWM (melodías). Con la placa solo por USB y sin batería, el LED funciona pero el buzzer no suena. Conectar la batería.
- **Cerrar el jumper JP1** si la placa se va a alimentar desde la batería (une la salida del regulador con +3,3 V).
- Prueba rápida sin gateway: app **nRF Connect** (iOS, gratis) → conectar a `UBICAJA_A` → característica `...d001` → escribir texto `SONAR`. Debe parpadear y tocar la melodía de búsqueda; el pulsador lo pasa a ENCONTRADA (LED fijo + melodía corta de confirmación).

## 3. Red y broker (laptop)

1. iPhone → Ajustes → Compartir Internet → activar **Maximizar compatibilidad** (el ESP32-C3 solo usa 2,4 GHz).
2. Conectar la laptop al hotspot del iPhone.
3. PowerShell **como administrador**, en la carpeta `archivos_fuente`:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\Demo\iniciar_demo.ps1
   ```
   El script detiene el servicio Mosquitto (que solo escucha en localhost), abre los puertos 1883/9001/8080 en el firewall, muestra la IP de la laptop (`172.20.10.x`), sirve la app web y arranca el broker en modo detallado.

## 4. Gateway (ESP32-C3 sin nada)

1. Copiar `secrets_example.h` como `secrets.h` y completar: nombre del hotspot, clave e IP de la laptop.
2. Cargar `Firmware/Gateway_ESP32C3`. En el monitor serie debe aparecer, en orden:
   `Wi-Fi OK, IP...` → `MQTT conectado` → `BLE: UBICAJA_A encontrada` → `BLE: UBICAJA_A conectada, estado=REPOSO`.
3. Si se queda en "Esperando Wi-Fi": revisar "Maximizar compatibilidad" y el nombre del hotspot (los apóstrofes del iPhone, como en "iPhone de Omar", deben copiarse exactos: suele ser `’` y no `'`). Lo más seguro es renombrar el iPhone a algo simple (Ajustes → General → Información → Nombre), por ejemplo `UBICAJA`.

## 5. App Flutter en el iPhone

Ya está compilada en `Flutter\build\web` (Flutter 3.50.1 en `F:\flutter_sdk`) y probada contra Mosquitto por WebSocket. No necesita internet: CanvasKit va incluido. Para recompilar tras un cambio:

```powershell
$env:PUB_CACHE='F:\flutter_sdk\pub_cache'; $env:PATH="F:\flutter_sdk\flutter\bin;$env:PATH"
cd Flutter
flutter build web --release --no-web-resources-cdn
```

Luego volver a ejecutar `iniciar_demo.ps1` y abrir en Safari `http://172.20.10.x:8080`. La app toma el broker del mismo host. "Agregar a pantalla de inicio" la deja con ícono propio.

Para probar en la laptop antes: `flutter run -d chrome --dart-define=MQTT_HOST=localhost`.

## 6. Respaldo si la app web falla: MQTTX (ya instalado en la laptop)

- Conectar a `localhost:1883`, suscribirse a `ubicaja/#`.
- Publicar `SONAR` en `ubicaja/comando/A`. Se ven `entrega = GATT_OK` y `estado = ALERTA`; al presionar el pulsador, `estado = ENCONTRADA`.

## Guion de la demo (2 minutos)

1. Mostrar la app: gateway CONECTADO, Caja A en REPOSO, enlace BLE_CONECTADA.
2. "Hacer sonar" → la etiqueta parpadea y suena; la tarjeta se pone amarilla (ALERTA).
3. Presionar el pulsador → LED fijo + melodía de confirmación, la tarjeta se pone verde (ENCONTRADA) en menos de 1 s.
4. A los 10 s vuelve sola a REPOSO.
5. Opcional: "Sonar" y no presionar nada; a los 120 s pasa a NO_ENCONTRADA (rojo). Para la demo conviene bajar `TIEMPO_MAX_BUSQUEDA_MS` a 20000.
6. Mostrar la pestaña Historial y la consola de Mosquitto con los mensajes.

## Checklist de la noche anterior

- [ ] Batería de la etiqueta cargada y jumper JP1 cerrado
- [ ] Cable USB de datos para el gateway (y uno de repuesto)
- [ ] Probar todo con el hotspot del iPhone, no con el Wi-Fi de casa
- [ ] Video de respaldo grabado del funcionamiento completo
- [ ] Batería del iPhone y cargador de la laptop
