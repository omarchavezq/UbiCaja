/* UbiCaja | Etiqueta BLE A/B | ESP32-C3, NimBLE-Arduino 2.x.
   GPIO4 LED (220 ohm), GPIO5 driver de buzzer activo, GPIO6 pulsador a GND.
   Compilar TAG_ID="A" y TAG_ID="B" para cada etiqueta. */
#include <Arduino.h>
#include <NimBLEDevice.h>

#define TAG_ID "A"
static constexpr int PIN_LED=4, PIN_BUZZER=5, PIN_BUTTON=6;
static const char* SERVICE_UUID="6f04d000-2c44-4a30-8aa8-cb12ae00c001";
static const char* CMD_UUID="6f04d001-2c44-4a30-8aa8-cb12ae00c001";
static const char* STATE_UUID="6f04d002-2c44-4a30-8aa8-cb12ae00c001";

enum Estado : uint8_t { REPOSO, ALERTA, ENCONTRADA, NO_ENCONTRADA };
Estado estado = REPOSO;
uint32_t inicioAlerta = 0;
uint32_t inicioResultado = 0;
constexpr uint32_t TIEMPO_MAX_BUSQUEDA_MS = 120000;
constexpr uint32_t MOSTRAR_RESULTADO_MS = 10000;
NimBLECharacteristic* estadoBle = nullptr;
uint32_t ultimoCambioBoton = 0;
bool botonAnterior = HIGH;

const char* nombreEstado(Estado e) {
  switch(e) { case REPOSO: return "REPOSO"; case ALERTA: return "ALERTA";
              case ENCONTRADA: return "ENCONTRADA"; }
  return "ERROR";
}
void publicarEstado() {
  if(estadoBle) { estadoBle->setValue(nombreEstado(estado)); estadoBle->notify(); }
  Serial.printf("TAG_%s;estado=%s;ms=%lu\n",TAG_ID,nombreEstado(estado),(unsigned long)millis());
}
void cambiarEstado(Estado nuevo) {
  if(nuevo == estado) return;
  estado=nuevo;
  if (nuevo==ALERTA) inicioAlerta=millis();
  if (nuevo==ENCONTRADA || nuevo==NO_ENCONTRADA) inicioResultado=millis();
  publicarEstado();
}
// La característica BLE admite órdenes explícitas, nunca una orden destinada a otro tag.
class ManejadorOrden : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo& info) override {
    String msg = String(c->getValue().c_str());
    if(msg == "SONAR") cambiarEstado(ALERTA);
    else if(msg == "DETENER") cambiarEstado(REPOSO);
  }
};
void setup(){
  Serial.begin(115200);
  pinMode(PIN_LED,OUTPUT); pinMode(PIN_BUZZER,OUTPUT); pinMode(PIN_BUTTON,INPUT_PULLUP);
  NimBLEDevice::init(String("UBICAJA_")+TAG_ID);
  NimBLEServer* servidor=NimBLEDevice::createServer();
  NimBLEService* servicio=servidor->createService(SERVICE_UUID);
  auto* cmd=servicio->createCharacteristic(CMD_UUID,NIMBLE_PROPERTY::WRITE);
  cmd->setCallbacks(new ManejadorOrden());
  estadoBle=servicio->createCharacteristic(STATE_UUID,NIMBLE_PROPERTY::READ|NIMBLE_PROPERTY::NOTIFY);
  estadoBle->setValue("REPOSO");
  servicio->start();
  NimBLEAdvertising* publicidad=NimBLEDevice::getAdvertising();
  publicidad->addServiceUUID(SERVICE_UUID); publicidad->start();
}
void loop(){
  bool boton=digitalRead(PIN_BUTTON);
  if(botonAnterior == HIGH && boton == LOW && millis()-ultimoCambioBoton > 80){
    ultimoCambioBoton=millis();
    if(estado==ALERTA) cambiarEstado(ENCONTRADA);
  }
  botonAnterior=boton;
  if(estado==ALERTA && millis()-inicioAlerta>=TIEMPO_MAX_BUSQUEDA_MS) cambiarEstado(NO_ENCONTRADA);
  if((estado==ENCONTRADA || estado==NO_ENCONTRADA) &&
     millis()-inicioResultado>=MOSTRAR_RESULTADO_MS) cambiarEstado(REPOSO);
  // La activación intermitente evita mantener buzzer y LED encendidos continuamente.
  bool pulso=(millis()/300)%2 == 0;
  bool activo=estado==ALERTA && pulso;
  digitalWrite(PIN_LED,activo?HIGH:LOW);
  digitalWrite(PIN_BUZZER,activo?HIGH:LOW);
  delay(15);
}
