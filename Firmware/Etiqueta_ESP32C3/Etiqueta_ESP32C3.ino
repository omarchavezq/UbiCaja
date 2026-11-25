/* UbiCaja | Etiqueta BLE A/B | ESP32-C3 SuperMini, NimBLE-Arduino 2.x.
   Pines según el esquemático del PCB (DIAGRAMA PCB.pdf):
     GPIO3 -> LED (R19 1k, activo en alto)
     GPIO4 -> pulsador "MUTE" (R18 10k pull-up + 100 nF, activo en bajo)
     GPIO5 -> buzzer PASIVO (MOSFET AO3400, buzzer alimentado desde VBAT)
   El buzzer es pasivo: se excita con PWM (LEDC) a la frecuencia de cada nota.
   El buzzer se alimenta de VBAT: sin batería conectada no suena.
   Compilar con TAG_ID "A" o "B" para cada etiqueta. */
#include <Arduino.h>
#include <NimBLEDevice.h>

#define TAG_ID "A"
static constexpr int PIN_LED=3, PIN_BUTTON=4, PIN_BUZZER=5;
static const char* SERVICE_UUID="6f04d000-2c44-4a30-8aa8-cb12ae00c001";
static const char* CMD_UUID="6f04d001-2c44-4a30-8aa8-cb12ae00c001";
static const char* STATE_UUID="6f04d002-2c44-4a30-8aa8-cb12ae00c001";

enum Estado : uint8_t { REPOSO, ALERTA, ENCONTRADA, NO_ENCONTRADA };
volatile Estado estado = REPOSO;
volatile int ordenRecibida = -1;           // la escribe el callback BLE, la procesa loop()
uint32_t inicioAlerta = 0;
uint32_t inicioResultado = 0;
constexpr uint32_t TIEMPO_MAX_BUSQUEDA_MS = 120000;
constexpr uint32_t MOSTRAR_RESULTADO_MS = 10000;
NimBLECharacteristic* estadoBle = nullptr;
uint32_t ultimoCambioBoton = 0;
bool botonAnterior = HIGH;

// ---------- Melodías para buzzer pasivo (reproducción sin bloquear el loop) ----------
struct Nota { uint16_t hz; uint16_t ms; };     // hz = 0 -> silencio
// Búsqueda: arpegio tipo órgano La m – Fa – Do – Sol, en bucle mientras dure la ALERTA.
#define ARP(r,q,o,t) {r,170},{q,170},{o,170},{q,170},{t,170},{q,170},{o,170},{q,170}
static const Nota MELODIA_BUSQUEDA[] = {
  ARP(440, 659,  880, 1047),   // La menor
  ARP(349, 523,  698,  880),   // Fa mayor
  ARP(523, 784, 1047, 1319),   // Do mayor
  ARP(392, 587,  784,  988),   // Sol mayor
  {0, 250}
};
// Encontrada: subida corta y alegre.
static const Nota MELODIA_ENCONTRADA[] = { {1047,90},{1319,90},{1568,90},{2093,260} };
// No encontrada: bajada.
static const Nota MELODIA_NO_ENCONTRADA[] = { {784,200},{659,200},{523,200},{392,450} };

const Nota* melodia = nullptr;
size_t largoMelodia = 0, indiceNota = 0;
bool repetirMelodia = false;
uint32_t finNota = 0;

void tocarNota(uint16_t hz) { ledcWriteTone(PIN_BUZZER, hz); }   // 0 Hz = silencio
template<size_t N> void iniciarMelodia(const Nota (&m)[N], bool repetir) {
  melodia = m; largoMelodia = N; indiceNota = 0; repetirMelodia = repetir;
  tocarNota(m[0].hz); finNota = millis() + m[0].ms;
}
void detenerMelodia() { melodia = nullptr; tocarNota(0); }
void actualizarMelodia() {
  if (!melodia || (int32_t)(millis() - finNota) < 0) return;
  if (++indiceNota >= largoMelodia) {
    if (!repetirMelodia) { detenerMelodia(); return; }
    indiceNota = 0;
  }
  tocarNota(melodia[indiceNota].hz);
  finNota = millis() + melodia[indiceNota].ms;
}

const char* nombreEstado(Estado e) {
  switch(e) {
    case REPOSO: return "REPOSO";
    case ALERTA: return "ALERTA";
    case ENCONTRADA: return "ENCONTRADA";
    case NO_ENCONTRADA: return "NO_ENCONTRADA";
  }
  return "ERROR";
}
void publicarEstado() {
  if(estadoBle) { estadoBle->setValue(std::string(nombreEstado(estado))); estadoBle->notify(); }
  Serial.printf("TAG_%s;estado=%s;ms=%lu\n",TAG_ID,nombreEstado(estado),(unsigned long)millis());
}
void cambiarEstado(Estado nuevo) {
  if(nuevo == estado) return;
  estado=nuevo;
  if (nuevo==ALERTA) inicioAlerta=millis();
  if (nuevo==ENCONTRADA || nuevo==NO_ENCONTRADA) inicioResultado=millis();
  switch (nuevo) {
    case ALERTA:        iniciarMelodia(MELODIA_BUSQUEDA, true); break;
    case ENCONTRADA:    iniciarMelodia(MELODIA_ENCONTRADA, false); break;
    case NO_ENCONTRADA: iniciarMelodia(MELODIA_NO_ENCONTRADA, false); break;
    case REPOSO:        detenerMelodia(); break;
  }
  publicarEstado();
}
// La característica BLE solo acepta órdenes explícitas.
class ManejadorOrden : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& info) override {
    std::string msg = c->getValue();
    if(msg == "SONAR") ordenRecibida = ALERTA;
    else if(msg == "DETENER") ordenRecibida = REPOSO;
  }
};
void setup(){
  Serial.begin(115200);
  pinMode(PIN_LED,OUTPUT); pinMode(PIN_BUTTON,INPUT_PULLUP);
  digitalWrite(PIN_LED,LOW);
  ledcAttach(PIN_BUZZER, 2000, 10);   // PWM para el buzzer pasivo (núcleo ESP32 3.x)
  tocarNota(0);
  NimBLEDevice::init("UBICAJA_" TAG_ID);
  NimBLEServer* servidor=NimBLEDevice::createServer();
  servidor->advertiseOnDisconnect(true);
  NimBLEService* servicio=servidor->createService(SERVICE_UUID);
  auto* cmd=servicio->createCharacteristic(CMD_UUID,NIMBLE_PROPERTY::WRITE);
  cmd->setCallbacks(new ManejadorOrden());
  estadoBle=servicio->createCharacteristic(STATE_UUID,NIMBLE_PROPERTY::READ|NIMBLE_PROPERTY::NOTIFY);
  estadoBle->setValue(std::string("REPOSO"));
  servicio->start();
  // El nombre va en el anuncio principal y el UUID de 128 bits en la respuesta de escaneo:
  // juntos no caben en los 31 bytes de un solo paquete.
  NimBLEAdvertisementData anuncio, respuesta;
  anuncio.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
  anuncio.setName("UBICAJA_" TAG_ID);
  respuesta.addServiceUUID(NimBLEUUID(SERVICE_UUID));
  NimBLEAdvertising* publicidad=NimBLEDevice::getAdvertising();
  publicidad->setAdvertisementData(anuncio);
  publicidad->setScanResponseData(respuesta);
  publicidad->start();
  Serial.println("UBICAJA_" TAG_ID " anunciando por BLE");
}
void loop(){
  if(ordenRecibida >= 0){ Estado e=(Estado)ordenRecibida; ordenRecibida=-1; cambiarEstado(e); }
  bool boton=digitalRead(PIN_BUTTON);
  if(botonAnterior == HIGH && boton == LOW && millis()-ultimoCambioBoton > 80){
    ultimoCambioBoton=millis();
    if(estado==ALERTA) cambiarEstado(ENCONTRADA);
  }
  botonAnterior=boton;
  if(estado==ALERTA && millis()-inicioAlerta>=TIEMPO_MAX_BUSQUEDA_MS) cambiarEstado(NO_ENCONTRADA);
  if((estado==ENCONTRADA || estado==NO_ENCONTRADA) &&
     millis()-inicioResultado>=MOSTRAR_RESULTADO_MS) cambiarEstado(REPOSO);
  // ALERTA: LED intermitente + melodía. ENCONTRADA: LED fijo. NO_ENCONTRADA: LED parpadeo lento.
  actualizarMelodia();
  bool pulso=(millis()/300)%2 == 0;
  bool led=(estado==ALERTA && pulso) || estado==ENCONTRADA ||
           (estado==NO_ENCONTRADA && (millis()/1000)%2==0);
  digitalWrite(PIN_LED,led?HIGH:LOW);
  delay(5);
}
