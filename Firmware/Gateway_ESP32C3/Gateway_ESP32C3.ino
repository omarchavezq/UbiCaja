/* UbiCaja | Pasarela ESP32-C3 Wi-Fi/MQTT/BLE GATT (NimBLE-Arduino 2.x, PubSubClient).
   - Lista de etiquetas dinámica: la app publica qué etiquetas están registradas
     (RAIZ/gateway/etiquetas, retenido, p. ej. "A,B") y la pasarela se conecta a ellas.
   - Descubrimiento: la app pide un escaneo (RAIZ/gateway/escanear) y la pasarela responde
     con las etiquetas UBICAJA_* cercanas y su RSSI (RAIZ/gateway/descubiertas).
   - Conexión BLE persistente con cada etiqueta registrada:
       órdenes SONAR/DETENER por escritura GATT inmediata,
       estados por notificación GATT (el pulsador se ve en la app en menos de 1 s),
       RSSI cada 5 s (RAIZ/etiqueta/ID/rssi) y reconexión automática. */
#include <WiFi.h>
#include <PubSubClient.h>
#include <NimBLEDevice.h>
#include "secrets.h"

// Raíz de los tópicos MQTT. En un broker público debe ser única (se define en secrets.h).
#ifndef MQTT_RAIZ
#define MQTT_RAIZ "ubicaja"
#endif
const String RAIZ = MQTT_RAIZ;

// Etiquetas que se usan hasta que la app publique su registro.
#define ETIQUETAS_POR_DEFECTO "A"
// Máximo de etiquetas simultáneas (límite de conexiones BLE de NimBLE en el C3).
const int MAX_ETIQUETAS = 3;

// Las placas ESP32-C3 SuperMini suelen fallar al conectar a Wi-Fi a potencia máxima.
#define REDUCIR_POTENCIA_WIFI 1

const char* SERVICE_UUID="6f04d000-2c44-4a30-8aa8-cb12ae00c001";
const char* CMD_UUID="6f04d001-2c44-4a30-8aa8-cb12ae00c001";
const char* STATE_UUID="6f04d002-2c44-4a30-8aa8-cb12ae00c001";

WiFiClient net; PubSubClient mqtt(net);
struct Etiqueta {
  String id="";                  // vacío = ranura libre
  NimBLEClient* cliente=nullptr;
  NimBLERemoteCharacteristic* cmd=nullptr;
  NimBLERemoteCharacteristic* estado=nullptr;
  char recibido[24]="";          // escrito por la notificación BLE (otra tarea)
  volatile bool hayNuevo=false;
  String estadoActual="";        // último estado conocido de la etiqueta
  String estadoPublicado="";     // último estado enviado a MQTT
  bool conectadaPublicada=false;
  bool enlacePublicado=false;    // ya se publicó al menos una vez el enlace
};
Etiqueta etiquetas[MAX_ETIQUETAS];
String ordenPendiente="";
String listaPendiente="";        // nueva lista de etiquetas recibida por MQTT
bool hayListaPendiente=false;
bool escaneoPedido=false;
uint32_t proximaBusqueda=0, proximoRssi=0;
portMUX_TYPE candado = portMUX_INITIALIZER_UNLOCKED;

int indiceDe(const String& id){
  if(!id.length()) return -1;
  for(int i=0;i<MAX_ETIQUETAS;i++) if(etiquetas[i].id==id) return i;
  return -1;
}
bool conectada(const Etiqueta& e){ return e.cliente && e.cliente->isConnected() && e.cmd && e.estado; }

void publicar(const String& topico,const String& valor,bool retener){
  if(mqtt.connected()) mqtt.publish(topico.c_str(),valor.c_str(),retener);
  Serial.printf("MQTT -> %s = %s\n",topico.c_str(),valor.c_str());
}

// Copia el valor recibido sin usar memoria dinámica (se llama desde la tarea de NimBLE).
void guardarRecibido(Etiqueta& e,const uint8_t* datos,size_t largo){
  if(largo>sizeof(e.recibido)-1) largo=sizeof(e.recibido)-1;
  portENTER_CRITICAL(&candado);
  memcpy(e.recibido,datos,largo); e.recibido[largo]=0; e.hayNuevo=true;
  portEXIT_CRITICAL(&candado);
}

void soltar(Etiqueta& e){
  if(e.cliente){
    if(e.cliente->isConnected()) e.cliente->disconnect();
    NimBLEDevice::deleteClient(e.cliente);
  }
  e.cliente=nullptr; e.cmd=nullptr; e.estado=nullptr;
}

// Aplica una lista "A,B,C": suelta las etiquetas que salieron y asigna ranuras a las nuevas.
void aplicarLista(String lista){
  lista.replace(" ","");
  Serial.printf("Registro de etiquetas: [%s]\n",lista.c_str());
  String ids[MAX_ETIQUETAS]; int n=0;
  while(lista.length() && n<MAX_ETIQUETAS){
    int coma=lista.indexOf(',');
    String id=coma<0?lista:lista.substring(0,coma);
    lista=coma<0?"":lista.substring(coma+1);
    if(id.length() && id.length()<=12) ids[n++]=id;
  }
  for(int i=0;i<MAX_ETIQUETAS;i++){
    if(!etiquetas[i].id.length()) continue;
    bool sigue=false; for(int k=0;k<n;k++) if(ids[k]==etiquetas[i].id) sigue=true;
    if(!sigue){
      Serial.printf("Etiqueta %s retirada\n",etiquetas[i].id.c_str());
      soltar(etiquetas[i]); etiquetas[i]=Etiqueta();
    }
  }
  for(int k=0;k<n;k++){
    if(indiceDe(ids[k])>=0) continue;
    for(int i=0;i<MAX_ETIQUETAS;i++) if(!etiquetas[i].id.length()){
      etiquetas[i]=Etiqueta(); etiquetas[i].id=ids[k];
      Serial.printf("Etiqueta %s agregada\n",ids[k].c_str());
      break;
    }
  }
  proximaBusqueda=0;   // buscar las nuevas de inmediato
}

void recibirMQTT(char* topic,byte* payload,unsigned int len){
  String t(topic), p="";
  for(unsigned i=0;i<len;i++)p+=char(payload[i]);
  p.trim();
  if(t==RAIZ+"/gateway/etiquetas"){ listaPendiente=p; hayListaPendiente=true; return; }
  if(t==RAIZ+"/gateway/escanear"){ escaneoPedido=true; return; }
  String base=RAIZ+"/comando/";
  if(!t.startsWith(base)) return;
  String id=t.substring(base.length());
  if(p=="SONAR" || p=="DETENER") ordenPendiente=id+":"+p;
}

void conectarMQTT(){
  if(mqtt.connected())return;
  static uint32_t proximo=0;
  if(millis()<proximo) return;
  proximo=millis()+3000;
  Serial.printf("Conectando a MQTT %s:%d ...\n",MQTT_HOST,MQTT_PORT);
  const char* usuario=strlen(MQTT_USER)?MQTT_USER:nullptr;
  const char* clave=strlen(MQTT_PASS)?MQTT_PASS:nullptr;
  // ID único por placa: en un broker público dos clientes con el mismo ID se expulsan entre sí.
  String idCliente="ubicaja_gw_"+String((uint32_t)ESP.getEfuseMac(),HEX);
  String topicoGw=RAIZ+"/gateway/estado";
  if(mqtt.connect(idCliente.c_str(),usuario,clave,topicoGw.c_str(),1,true,"DESCONECTADO")) {
    mqtt.subscribe((RAIZ+"/comando/#").c_str());
    mqtt.subscribe((RAIZ+"/gateway/etiquetas").c_str());
    mqtt.subscribe((RAIZ+"/gateway/escanear").c_str());
    publicar(topicoGw,"CONECTADO",true);
    for(int i=0;i<MAX_ETIQUETAS;i++){
      etiquetas[i].estadoPublicado="";   // fuerza republicar estados tras reconectar
      etiquetas[i].enlacePublicado=false;
    }
    Serial.println("MQTT conectado");
  } else Serial.printf("MQTT fallo rc=%d\n",mqtt.state());
}

// Conecta a un dispositivo ya encontrado en el escaneo, suscribe notificaciones y lee el estado.
bool conectarA(Etiqueta& e,const NimBLEAdvertisedDevice* d){
  soltar(e);
  Serial.printf("BLE: UBICAJA_%s encontrada (RSSI %d), conectando...\n",e.id.c_str(),d->getRSSI());
  NimBLEClient* cli=NimBLEDevice::createClient();
  if(!cli->connect(d)){ NimBLEDevice::deleteClient(cli); Serial.println("BLE: fallo al conectar"); return false; }
  NimBLERemoteService* svc=cli->getService(SERVICE_UUID);
  NimBLERemoteCharacteristic* cc=svc?svc->getCharacteristic(CMD_UUID):nullptr;
  NimBLERemoteCharacteristic* ce=svc?svc->getCharacteristic(STATE_UUID):nullptr;
  if(!cc || !ce){ cli->disconnect(); NimBLEDevice::deleteClient(cli); Serial.println("BLE: servicio GATT no valido"); return false; }
  e.cliente=cli; e.cmd=cc; e.estado=ce;
  int idx=&e-etiquetas;
  if(ce->canNotify())
    ce->subscribe(true,[idx](NimBLERemoteCharacteristic*,uint8_t* d,size_t l,bool){ guardarRecibido(etiquetas[idx],d,l); });
  String actual=String(ce->readValue().c_str());
  if(actual.length()) e.estadoActual=actual;
  Serial.printf("BLE: UBICAJA_%s conectada, estado=%s\n",e.id.c_str(),actual.c_str());
  return true;
}

// Un solo escaneo sirve para: reconectar etiquetas registradas y responder al descubrimiento.
void escanearYConectar(bool informar){
  NimBLEScan* scan=NimBLEDevice::getScan();
  scan->setActiveScan(true);
  NimBLEScanResults res=scan->getResults(informar?3000:2000,false);
  String descubiertas="";
  for(int i=0;i<res.getCount();i++){
    const NimBLEAdvertisedDevice* d=res.getDevice(i);
    String nombre=String(d->getName().c_str());
    if(!nombre.startsWith("UBICAJA_") || nombre=="UBICAJA_GATEWAY") continue;
    String id=nombre.substring(8);
    if(informar){
      if(descubiertas.length()) descubiertas+=",";
      descubiertas+=id+":"+String(d->getRSSI());
    }
    int k=indiceDe(id);
    if(k>=0 && !conectada(etiquetas[k])){ conectarA(etiquetas[k],d); mqtt.loop(); }
  }
  scan->clearResults();
  if(informar){
    // Las etiquetas ya conectadas no anuncian, pero también están cerca: se incluyen.
    for(int i=0;i<MAX_ETIQUETAS;i++) if(conectada(etiquetas[i]) && descubiertas.indexOf(etiquetas[i].id+":")!=0
                                         && descubiertas.indexOf(","+etiquetas[i].id+":")<0){
      if(descubiertas.length()) descubiertas+=",";
      descubiertas+=etiquetas[i].id+":"+String(etiquetas[i].cliente->getRssi());
    }
    publicar(RAIZ+"/gateway/descubiertas",descubiertas.length()?descubiertas:"NINGUNA",false);
  }
}

void setup(){
  Serial.begin(115200);
  delay(300);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID,WIFI_PASS);
#if REDUCIR_POTENCIA_WIFI
  WiFi.setTxPower(WIFI_POWER_8_5dBm);
#endif
  WiFi.setAutoReconnect(true);
  NimBLEDevice::init("UBICAJA_GATEWAY");
  aplicarLista(ETIQUETAS_POR_DEFECTO);
  mqtt.setServer(MQTT_HOST,MQTT_PORT);
  mqtt.setCallback(recibirMQTT);
  mqtt.setBufferSize(512);
  mqtt.setSocketTimeout(3);
  Serial.printf("UbiCaja gateway. Wi-Fi: %s | raiz MQTT: %s\n",WIFI_SSID,MQTT_RAIZ);
}

void loop(){
  static uint32_t avisoWifi=0;
  if(WiFi.status()!=WL_CONNECTED){
    if(millis()>avisoWifi){ avisoWifi=millis()+2000; Serial.println("Esperando Wi-Fi..."); }
    delay(100); return;
  }
  static bool ipMostrada=false;
  if(!ipMostrada){ ipMostrada=true; Serial.print("Wi-Fi OK, IP: "); Serial.println(WiFi.localIP()); }
  conectarMQTT(); mqtt.loop();

  if(hayListaPendiente){ hayListaPendiente=false; aplicarLista(listaPendiente); }

  // 1) Orden de la app -> escritura GATT inmediata.
  if(ordenPendiente.length()){
    String msg=ordenPendiente; ordenPendiente="";
    int sep=msg.indexOf(':');
    String id=msg.substring(0,sep), orden=msg.substring(sep+1);
    int i=indiceDe(id);
    bool ok=false;
    if(i>=0 && !conectada(etiquetas[i])) escanearYConectar(false);
    if(i>=0 && conectada(etiquetas[i]))
      ok=etiquetas[i].cmd->writeValue((const uint8_t*)orden.c_str(),orden.length(),true);
    publicar(RAIZ+"/etiqueta/"+id+"/entrega",ok?"GATT_OK":"NO_ENCONTRADA",false);
  }

  // 2) Descubrimiento pedido por la app, o reconexión periódica de las registradas.
  bool falta=false;
  for(int i=0;i<MAX_ETIQUETAS;i++) if(etiquetas[i].id.length() && !conectada(etiquetas[i])) falta=true;
  if(escaneoPedido){ escaneoPedido=false; escanearYConectar(true); proximaBusqueda=millis()+5000; }
  else if(falta && millis()>=proximaBusqueda){ escanearYConectar(false); proximaBusqueda=millis()+5000; }

  // 3) Enlace, estados y RSSI hacia MQTT.
  bool tocaRssi=millis()>=proximoRssi;
  if(tocaRssi) proximoRssi=millis()+5000;
  for(int i=0;i<MAX_ETIQUETAS;i++){
    Etiqueta& e=etiquetas[i];
    if(!e.id.length()) continue;
    bool c=conectada(e);
    if(!e.enlacePublicado || c!=e.conectadaPublicada){
      e.enlacePublicado=true; e.conectadaPublicada=c;
      publicar(RAIZ+"/etiqueta/"+e.id+"/enlace",c?"BLE_CONECTADA":"BLE_PERDIDA",true);
    }
    if(e.hayNuevo){
      char copia[24];
      portENTER_CRITICAL(&candado); memcpy(copia,e.recibido,sizeof(copia)); e.hayNuevo=false; portEXIT_CRITICAL(&candado);
      if(copia[0]) e.estadoActual=String(copia);
    }
    if(e.estadoActual.length() && e.estadoActual!=e.estadoPublicado && mqtt.connected()){
      e.estadoPublicado=e.estadoActual;
      publicar(RAIZ+"/etiqueta/"+e.id+"/estado",e.estadoActual,true);
    }
    if(tocaRssi && c && mqtt.connected())
      mqtt.publish((RAIZ+"/etiqueta/"+e.id+"/rssi").c_str(),String(e.cliente->getRssi()).c_str(),false);
  }
  delay(10);
}
