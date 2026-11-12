/* UbiCaja | Pasarela ESP32-C3 Wi-Fi/MQTT/BLE GATT.
   Comunicación bidireccional: orden, entrega GATT y lectura de estado. */
#include <WiFi.h>
#include <PubSubClient.h>
#include <NimBLEDevice.h>
#include "secrets.h"

const char* SERVICE_UUID="6f04d000-2c44-4a30-8aa8-cb12ae00c001";
const char* CMD_UUID="6f04d001-2c44-4a30-8aa8-cb12ae00c001";
const char* STATE_UUID="6f04d002-2c44-4a30-8aa8-cb12ae00c001";
WiFiClient net; PubSubClient mqtt(net);
String ordenPendiente="";
String estadosPublicados[2]={"", ""};
uint32_t siguienteSondeo=0;


void recibirMQTT(char* topic,byte* payload,unsigned int len){
  String t(topic), p="";
  for(unsigned i=0;i<len;i++)p+=char(payload[i]);
  if((t=="ubicaja/comando/A" || t=="ubicaja/comando/B") &&
      (p=="SONAR" || p=="DETENER"))
    ordenPendiente=(t.endsWith("/A")?"A":"B") + String(":")+p;
}
void conectarMQTT(){
  if(mqtt.connected())return;
  if(mqtt.connect("ubicaja_gateway",MQTT_USER,MQTT_PASS)) {
    mqtt.subscribe("ubicaja/comando/A"); mqtt.subscribe("ubicaja/comando/B");
    mqtt.publish("ubicaja/gateway/estado","CONECTADO",true);
  }
}
// Encuentra por nombre y comunica a la etiqueta elegida; lectura GATT de estado.
bool comunicarEtiqueta(const String& tag,const String& cmd,bool enviarOrden){
  NimBLEScan* scan=NimBLEDevice::getScan();
  NimBLEScanResults encontrados=scan->getResults(2500,false);
  bool entregada=false;
  for(int i=0;i<encontrados.getCount();i++){
    const NimBLEAdvertisedDevice* dev=encontrados.getDevice(i);
    if(String(dev->getName().c_str())!=String("UBICAJA_")+tag)continue;
    NimBLEClient* cliente=NimBLEDevice::createClient();
    if(cliente->connect(dev)){
      auto* svc=cliente->getService(SERVICE_UUID);
      auto* carCmd=svc?svc->getCharacteristic(CMD_UUID):nullptr;
      auto* carEstado=svc?svc->getCharacteristic(STATE_UUID):nullptr;
      if(!enviarOrden) entregada=(carEstado!=nullptr);
      else if(carCmd && carCmd->canWrite()) {
        entregada=carCmd->writeValue((uint8_t*)cmd.c_str(),cmd.length(),true);
      }
      if(carEstado && carEstado->canRead()){
        String estadoActual=String(carEstado->readValue().c_str());
        int idx=(tag=="A")?0:1;
        if(estadoActual.length() && estadoActual!=estadosPublicados[idx]){
          estadosPublicados[idx]=estadoActual;
          String topico="ubicaja/etiqueta/"+tag+"/estado";
          mqtt.publish(topico.c_str(),estadoActual.c_str(),true);
          Serial.printf("Etiqueta %s: %s\n",tag.c_str(),estadoActual.c_str());
        }
      }
      cliente->disconnect();
    }
    NimBLEDevice::deleteClient(cliente);
    break;
  }
  scan->clearResults();
  return entregada;
}
void setup(){
  Serial.begin(115200);
  WiFi.begin(WIFI_SSID,WIFI_PASS);
  NimBLEDevice::init("UBICAJA_GATEWAY");
  mqtt.setServer(MQTT_HOST,MQTT_PORT);
  mqtt.setCallback(recibirMQTT);
  mqtt.setBufferSize(256);
}
void loop(){
  if(WiFi.status()!=WL_CONNECTED){delay(500);return;}
  conectarMQTT();mqtt.loop();
  if(ordenPendiente.length()){
    String msg=ordenPendiente;ordenPendiente="";
    String tag=msg.substring(0,1), cmd=msg.substring(2);
    bool ok=comunicarEtiqueta(tag,cmd,true);
    String topic="ubicaja/etiqueta/"+tag+"/entrega";
    mqtt.publish(topic.c_str(),ok?"GATT_OK":"NO_ENCONTRADA",false);
  }
  // Sondeo breve de ambos estados para detectar CONFIRMACION y TIMEOUT físicos.
  if(millis()>=siguienteSondeo && mqtt.connected()){
    siguienteSondeo=millis()+9000;
    comunicarEtiqueta("A","",false);
    comunicarEtiqueta("B","",false);
  }
  delay(20);
}
