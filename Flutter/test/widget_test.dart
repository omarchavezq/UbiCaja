import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ubicaja/main.dart';

void main() {
  testWidgets('Sin cajas registradas muestra la invitación a agregar una', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const UbiCajaApp(iniciarConexion: false));
    expect(find.text('UbiCaja · Buscar'), findsOneWidget);
    expect(find.text('Aún no hay cajas registradas'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
  });
}
