/* UbiCaja - simulación de la máquina de estados de una etiqueta.
   En monitor serial enviar SONAR o DETENER; pulsador confirma búsqueda.
   El sketch simula solo señales digitales; BLE y MQTT se programan en los firmwares.
*/
#include <Arduino.h>
constexpr int LED_PIN=4, BUZZER_PIN=5, BUTTON_PIN=6;
constexpr uint32_t MAX_ALERTA_MS=120000, RESULTADO_MS=10000;
enum Estado {REPOSO,ALERTA,ENCONTRADA,NO_ENCONTRADA};
Estado estado=REPOSO;
uint32_t inicioAlerta=0,inicioResultado=0;
int anteriorBoton=HIGH;

const char* nombre(Estado e){switch(e){case REPOSO:return "REPOSO";case ALERTA:return "ALERTA";case ENCONTRADA:return "ENCONTRADA";case NO_ENCONTRADA:return "NO_ENCONTRADA";}return "?";}
void cambiar(Estado e){
 if(e==estado)return; estado=e;
 if(e==ALERTA)inicioAlerta=millis();
 if(e==ENCONTRADA || e==NO_ENCONTRADA)inicioResultado=millis();
 Serial.print("UbiCaja;estado=");Serial.println(nombre(estado));
}
void setup(){
 Serial.begin(115200);
 pinMode(LED_PIN,OUTPUT);pinMode(BUZZER_PIN,OUTPUT);pinMode(BUTTON_PIN,INPUT_PULLUP);
 Serial.println("UBICAJA: enviar SONAR / DETENER; presionar boton para confirmar.");
}
void loop(){
 if(Serial.available()){
  String cmd=Serial.readStringUntil('\n');cmd.trim();cmd.toUpperCase();
  if(cmd=="SONAR")cambiar(ALERTA);
  else if(cmd=="DETENER")cambiar(REPOSO);
 }
 int boton=digitalRead(BUTTON_PIN);
 if(anteriorBoton==HIGH && boton==LOW && estado==ALERTA)cambiar(ENCONTRADA);
 anteriorBoton=boton;
 if(estado==ALERTA && millis()-inicioAlerta>=MAX_ALERTA_MS)cambiar(NO_ENCONTRADA);
 if((estado==ENCONTRADA || estado==NO_ENCONTRADA) && millis()-inicioResultado>=RESULTADO_MS)cambiar(REPOSO);
 bool activo=(estado==ALERTA) && ((millis()/300)%2==0);
 digitalWrite(LED_PIN,activo?HIGH:LOW);
 if(activo)tone(BUZZER_PIN,1800);else noTone(BUZZER_PIN);
 delay(20);
}
