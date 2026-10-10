import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/screens/history_screen.dart';
import 'package:coswim/screens/session_detail_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

void main() {
  setUpAll(initSpanishDates);

  Future<void> pumpHistory(WidgetTester tester, List<SwimSession> sessions) async {
    final state = await buildAppState(sessions: sessions, signedIn: false);
    await pumpScreen(tester, HistoryScreen(appState: state));
  }

  testWidgets('muestra el título', (tester) async {
    await pumpHistory(tester, []);
    expect(find.text('Historial de Sesiones'), findsOneWidget);
  });

  testWidgets('sin sesiones muestra el estado vacío', (tester) async {
    await pumpHistory(tester, []);
    expect(find.text('No hay historial registrado'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('una tarjeta por sesión', (tester) async {
    await pumpHistory(tester, [buildSession(id: 'a'), buildSession(id: 'b', distance: 2000)]);
    expect(find.byType(Card), findsNWidgets(2));
  });

  testWidgets('muestra distancia y duración', (tester) async {
    await pumpHistory(tester, [buildSession(distance: 1500, durationSeconds: 1800)]);
    expect(find.text('1500 m'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
  });

  testWidgets('muestra el ritmo, la FC promedio y la SpO2', (tester) async {
    await pumpHistory(tester, [buildSession(distance: 1000, durationSeconds: 1200, spo2: 97)]);
    expect(find.text('2:00 min/100m'), findsOneWidget);
    expect(find.textContaining('BPM'), findsOneWidget);
    expect(find.text('97%'), findsOneWidget);
  });

  testWidgets('sin FC ni SpO2 muestra N/A', (tester) async {
    await pumpHistory(tester, [bareSession()]);
    expect(find.text('N/A'), findsNWidgets(2));
  });

  testWidgets('la fecha se muestra en español', (tester) async {
    await pumpHistory(tester, [buildSession(start: DateTime(2026, 1, 15, 8, 5))]);
    expect(find.textContaining('enero'), findsOneWidget);
    expect(find.textContaining('08:05'), findsOneWidget);
  });

  testWidgets('sin alertas no muestra el aviso', (tester) async {
    await pumpHistory(tester, [buildSession(spo2: 97, waterTemperature: 27)]);
    expect(find.text('Alertas'), findsNothing);
  });

  testWidgets('SpO2 baja muestra el aviso de alertas', (tester) async {
    await pumpHistory(tester, [bareSession(spo2: 92)]);
    expect(find.text('Alertas'), findsOneWidget);
  });

  testWidgets('agua fuera de rango muestra el aviso de alertas', (tester) async {
    await pumpHistory(tester, [bareSession(waterTemperature: 35)]);
    expect(find.text('Alertas'), findsOneWidget);
  });

  testWidgets('FC sostenida sobre el 90% muestra el aviso de alertas', (tester) async {
    // edad 22 → FC máx 198 → 90% = 178.2; 70 lecturas seguidas a 190.
    final hr = [
      for (var i = 0; i < 70; i++) HeartRatePoint(time: kStart.add(Duration(seconds: i)), bpm: 190),
    ];
    final session = SwimSession(
      id: 'alerta',
      startTime: kStart,
      endTime: kStart.add(const Duration(minutes: 10)),
      distance: 500,
      calories: 100,
      heartRateSeries: hr,
    );
    await pumpHistory(tester, [session]);
    expect(find.text('Alertas'), findsOneWidget);
  });

  testWidgets('tocar una sesión abre su detalle', (tester) async {
    await pumpHistory(tester, [buildSession()]);
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.byType(SessionDetailScreen), findsOneWidget);
  });
}
