import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() => runApp(const UbiCajaApp());

class UbiCajaApp extends StatelessWidget {
  const UbiCajaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'UbiCaja', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF00858E), useMaterial3: true),
    home: const PanelUbiCaja(),
  );
}

class PanelUbiCaja extends StatefulWidget {
  const PanelUbiCaja({super.key});
  @override State<PanelUbiCaja> createState() => _PanelUbiCajaState();
}

class _PanelUbiCajaState extends State<PanelUbiCaja> {
  static const host = String.fromEnvironment('MQTT_HOST', defaultValue:'192.168.1.100');
  static const port = int.fromEnvironment('MQTT_PORT', defaultValue:1883);
  static const username = String.fromEnvironment('MQTT_USER', defaultValue:'');
  static const password = String.fromEnvironment('MQTT_PASS', defaultValue:'');
  MqttServerClient? client;
  StreamSubscription? subscription;
  bool connected=false;
  int tab=0;
  final Map<String,String> estados={'A':'SIN DATOS','B':'SIN DATOS'};
  final Map<String,String> entregas={'A':'—','B':'—'};
  final List<String> historial=[];

  @override void initState(){ super.initState(); conectar(); }
  Future<void> conectar() async {
    final c=MqttServerClient.withPort(host,'ubicaja_app_${DateTime.now().millisecondsSinceEpoch}',port);
    c.logging(on:false); c.keepAlivePeriod=30; c.autoReconnect=true;
    c.onDisconnected=(){if(mounted) setState(()=>connected=false);};
    c.connectionMessage=MqttConnectMessage().withClientIdentifier(c.clientIdentifier)
      .startClean().withWillTopic('ubicaja/app/estado').withWillMessage('DESCONECTADO')
      .withWillQos(MqttQos.atLeastOnce);
    try {
      if(username.isEmpty){await c.connect();} else {await c.connect(username,password);}
      if(c.connectionStatus?.state!=MqttConnectionState.connected) {
        c.disconnect(); return;
      }
      client=c;
      c.subscribe('ubicaja/etiqueta/+/estado',MqttQos.atLeastOnce);
      c.subscribe('ubicaja/etiqueta/+/entrega',MqttQos.atLeastOnce);
      c.subscribe('ubicaja/gateway/estado',MqttQos.atLeastOnce);
      if(mounted)setState(()=>connected=true);
      subscription=c.updates?.listen((events){
        for(final m in events){
          final topic=m.topic;
          final payload=MqttPublishPayload.bytesToStringAsString(
            (m.payload as MqttPublishMessage).payload.message);
          if(!mounted)continue;
          setState((){
            final parts=topic.split('/');
            if(parts.length==4 && ['A','B'].contains(parts[2])){
              final id=parts[2];
              if(parts[3]=='estado')estados[id]=payload;
              if(parts[3]=='entrega')entregas[id]=payload;
              historial.insert(0,'${DateTime.now().toLocal().toIso8601String()} • Caja $id • ${parts[3]}: $payload');
            }
          });
        }
      });
    } catch(_){c.disconnect(); if(mounted)setState(()=>connected=false);}
  }
  void enviar(String id,String cmd) {
    final c=client;
    if(c==null || c.connectionStatus?.state!=MqttConnectionState.connected)return;
    final builder=MqttClientPayloadBuilder()..addString(cmd);
    c.publishMessage('ubicaja/comando/$id',MqttQos.atLeastOnce,builder.payload!);
    setState(()=>historial.insert(0,'${DateTime.now().toLocal().toIso8601String()} • Caja $id • orden $cmd'));
  }
  @override void dispose(){ subscription?.cancel(); client?.disconnect(); super.dispose(); }
  @override Widget build(BuildContext context) {
    Widget content;
    if(tab==0) {
      content=ListView(children:[
        Card(child:ListTile(leading:Icon(connected?Icons.cloud_done:Icons.cloud_off),
          title:Text(connected?'Conectado al gateway MQTT':'Sin conexión MQTT'),
          subtitle:Text('Broker: $host:$port'),
          trailing:IconButton(icon:const Icon(Icons.refresh),onPressed:conectar))),
        for(final id in ['A','B'])Card(child:ListTile(
          leading:const Icon(Icons.inventory_2_outlined),title:Text('Caja $id'),
          subtitle:Text('Estado: ${estados[id]}'),
          trailing:FilledButton(onPressed:connected?()=>enviar(id,'SONAR'):null,
            child:const Text('Hacer sonar'))))]);
    } else if(tab==1) {
      content=ListView(children:[for(final id in ['A','B'])Card(child:Column(children:[
        ListTile(title:Text('Etiqueta $id'),subtitle:Text('Estado: ${estados[id]}  •  Entrega: ${entregas[id]}')),
        Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
          TextButton(onPressed:connected?()=>enviar(id,'SONAR'):null,child:const Text('Sonar')),
          TextButton(onPressed:connected?()=>enviar(id,'DETENER'):null,child:const Text('Detener'))])]))]);
    } else {
      content=historial.isEmpty ? const Center(child:Text('El historial aparecerá al recibir eventos'))
        : ListView(children:[for(final e in historial)ListTile(leading:const Icon(Icons.history),title:Text(e))]);
    }
    return Scaffold(appBar:AppBar(title:const Text('UbiCaja')),
      body:Padding(padding:const EdgeInsets.all(14),child:content),
      bottomNavigationBar:NavigationBar(selectedIndex:tab,
        onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
          NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'Cajas'),
          NavigationDestination(icon:Icon(Icons.sensors),label:'Estados'),
          NavigationDestination(icon:Icon(Icons.history),label:'Historial'),
        ]));
  }
}
