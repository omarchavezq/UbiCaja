#pragma once
// Copiar como secrets.h (misma carpeta) y completar. No publicar credenciales.
// Hotspot del iPhone con "Maximizar compatibilidad" ACTIVADO (el ESP32-C3 solo usa 2,4 GHz).
#define WIFI_SSID "UBICAJA"            // nombre exacto del hotspot
#define WIFI_PASS "CAMBIAR"

// --- Opción A (recomendada): broker en la nube, no hace falta laptop ---
#define MQTT_HOST "broker.hivemq.com"
#define MQTT_PORT 1883
#define MQTT_USER ""
#define MQTT_PASS ""
#define MQTT_RAIZ "ubicaja_t3_mc3que"   // raíz única de tópicos; la app web usa la misma

// --- Opción B: broker local en la laptop (Demo/iniciar_demo.ps1) ---
// #define MQTT_HOST "172.20.10.2"     // IP de la laptop en el hotspot (ver ipconfig)
// #define MQTT_PORT 1883
// #define MQTT_USER ""
// #define MQTT_PASS ""
// #define MQTT_RAIZ "ubicaja"
