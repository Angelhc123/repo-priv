import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/screens/charts_screen.dart';
import 'package:coswim/services/app_state.dart';
import 'package:coswim/widgets/charts/heart_rate_series_chart.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

const _tall = Size(1400, 4000);

void main() {
  setUpAll(initSpanishDates);

  Future<AppState> pumpCharts(WidgetTester tester, List<SwimSession> sessions,
      {UserProfile? profile, StubHealthService? health}) async {
    final state = await buildAppState(
      sessions: sessions,
      profile: profile,
      signedIn: false,
      health: health,
    );
    await pumpScreen(tester, ChartsScreen(appState: state), size: _tall);
    await tester.pumpAndSettle();
    return state;
  }

  Text recordValue(WidgetTester tester, String label) {
    final column = find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
    final texts = find.descendant(of: column, matching: find.byType(Text));
    return tester.widget<Text>(texts.first);
  }

  testWidgets('sin sesiones muestra el estado de carga', (tester) async {
    await pumpCharts(tester, []);
    expect(find.text('Cargando gráficos...'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('muestra las 6 tarjetas de gráficos', (tester) async {
    await pumpCharts(tester, buildHistory(5));
    for (final title in [
      'Distancia Nadada por Sesión',
      'Frecuencia Cardíaca Continua',
      'Calorías Quemadas por Semana',
      'Saturación de Oxígeno (SpO2)',
      'Ritmo Promedio por Sesión',
      'Índice de Eficiencia',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('dibuja gráficos de línea y de barras', (tester) async {
    await pumpCharts(tester, buildHistory(5));
    expect(find.byType(LineChart), findsNWidgets(5));
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('el gráfico de FC usa la sesión más reciente por defecto', (tester) async {
    final history = buildHistory(3);
    await pumpCharts(tester, history);
    final chart = tester.widget<HeartRateSeriesChart>(find.byType(HeartRateSeriesChart));
    expect(chart.session!.id, history.first.id);
  });

  testWidgets('el selector permite elegir otra sesión', (tester) async {
    final history = buildHistory(3);
    await pumpCharts(tester, history);
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    final label = '${history.last.distance.toInt()}m)';
    await tester.tap(find.textContaining(label).last);
    await tester.pumpAndSettle();
    final chart = tester.widget<HeartRateSeriesChart>(find.byType(HeartRateSeriesChart));
    expect(chart.session!.id, history.last.id);
  });

  testWidgets('el selector lista una opción por sesión', (tester) async {
    await pumpCharts(tester, buildHistory(4));
    final dropdown = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(dropdown.items, hasLength(4));
  });

  testWidgets('muestra los cuatro récords', (tester) async {
    await pumpCharts(tester, buildHistory(3));
    for (final label in ['Mejor 100m', 'Mayor distancia', 'Mejor índice', 'Tendencia']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('mayor distancia toma el máximo del historial', (tester) async {
    await pumpCharts(tester, buildHistory(4)); // 800, 900, 1000, 1100
    expect(find.text('1100 m'), findsOneWidget);
  });

  testWidgets('mejor 100m sale de los splits de velocidad', (tester) async {
    // velocidades 0.9, 1.0, 1.1 m/s → la mejor es 1.1 → 90.9 s ≈ 1:31.
    await pumpCharts(tester, buildHistory(3));
    expect(find.text('1:31/100m'), findsOneWidget);
  });

  testWidgets('sin velocidad el mejor 100m queda en --:--', (tester) async {
    await pumpCharts(tester, [buildSession(withSpeed: false)]);
    expect(recordValue(tester, 'Mejor 100m').data, '--:--');
  });

  testWidgets('con pocas sesiones la tendencia dice "Sin datos suficientes"', (tester) async {
    await pumpCharts(tester, buildHistory(3));
    expect(find.text('Sin datos suficientes'), findsOneWidget);
  });

  testWidgets('tendencia estable cuando el índice no cambia', (tester) async {
    final sessions = [
      for (var i = 0; i < 6; i++)
        buildSession(id: 'e$i', start: kStart.subtract(Duration(days: i * 2))),
    ];
    await pumpCharts(tester, sessions);
    expect(find.text('Estable'), findsOneWidget);
  });

  testWidgets('tendencia "Mejorando" cuando las últimas sesiones son más rápidas', (tester) async {
    // La lista va de la más reciente a la más vieja: las 3 primeras rápidas.
    final sessions = [
      for (var i = 0; i < 6; i++)
        buildSession(
          id: 'm$i',
          start: kStart.subtract(Duration(days: i * 2)),
          durationSeconds: i < 3 ? 900 : 1500,
        ),
    ];
    await pumpCharts(tester, sessions);
    expect(find.text('Mejorando'), findsOneWidget);
  });

  testWidgets('tendencia "Empeorando" cuando las últimas sesiones son más lentas', (tester) async {
    final sessions = [
      for (var i = 0; i < 6; i++)
        buildSession(
          id: 'w$i',
          start: kStart.subtract(Duration(days: i * 2)),
          durationSeconds: i < 3 ? 1500 : 900,
        ),
    ];
    await pumpCharts(tester, sessions);
    expect(find.text('Empeorando'), findsOneWidget);
  });

  testWidgets('sin FC el índice de eficiencia avisa que faltan datos', (tester) async {
    await pumpCharts(tester, [bareSession()]);
    expect(find.text('Faltan datos de ritmo o FC para calcular el índice'), findsOneWidget);
    expect(recordValue(tester, 'Mejor índice').data, '--');
  });

  testWidgets('calorías agrupadas en las tres semanas', (tester) async {
    await pumpCharts(tester, buildHistory(8, gapDays: 3)); // cubre ~3 semanas
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final rods = chart.data.barGroups.map((g) => g.barRods.single.toY).toList();
    expect(rods, hasLength(3));
    expect(rods.every((v) => v > 0), isTrue);
  });

  testWidgets('las SpO2 bajas también se grafican', (tester) async {
    final sessions = [
      bareSession(id: 'a', spo2: 88, start: kStart),
      bareSession(id: 'b', spo2: 93, start: kStart.subtract(const Duration(days: 1))),
      bareSession(id: 'c', spo2: 98, start: kStart.subtract(const Duration(days: 2))),
      bareSession(id: 'd', start: kStart.subtract(const Duration(days: 3))),
    ];
    await pumpCharts(tester, sessions);
    final spo2Chart = tester
        .widgetList<LineChart>(find.byType(LineChart))
        .firstWhere((c) => c.data.minY == 80);
    expect(spo2Chart.data.lineBarsData.single.spots.map((s) => s.y), [98, 93, 88]);
  });

  testWidgets('el gráfico de ritmo agrega la línea del mejor tramo si hay splits', (tester) async {
    await pumpCharts(tester, buildHistory(3));
    final speed = tester
        .widgetList<LineChart>(find.byType(LineChart))
        .firstWhere((c) => c.data.minY == 0 && c.data.lineBarsData.length == 2);
    expect(speed.data.lineBarsData.last.dashArray, [4, 4]);
  });

  testWidgets('sin splits el gráfico de ritmo tiene una sola línea', (tester) async {
    await pumpCharts(tester, [bareSession()]);
    final speed = tester
        .widgetList<LineChart>(find.byType(LineChart))
        .where((c) => c.data.minY == 0)
        .toList();
    expect(speed.single.data.lineBarsData, hasLength(1));
  });

  testWidgets('si la sesión elegida desaparece vuelve a la primera', (tester) async {
    final health = StubHealthService(sessions: buildHistory(3));
    final state = await pumpCharts(tester, health.sessions, health: health);
    final first = state.sessions.first.id;

    health.sessions = [buildSession(id: 'nueva')];
    await state.refreshData();
    await tester.pumpWidget(MaterialApp(home: ChartsScreen(appState: state)));
    await tester.pumpAndSettle();

    final chart = tester.widget<HeartRateSeriesChart>(find.byType(HeartRateSeriesChart));
    expect(chart.session!.id, 'nueva');
    expect(chart.session!.id, isNot(first));
  });

  testWidgets('si el historial queda vacío vuelve al estado de carga', (tester) async {
    final health = StubHealthService(sessions: buildHistory(2));
    final state = await pumpCharts(tester, health.sessions, health: health);
    health.sessions = [];
    await state.refreshData();
    await tester.pumpWidget(MaterialApp(home: ChartsScreen(appState: state)));
    await tester.pumpAndSettle();
    expect(find.text('Cargando gráficos...'), findsOneWidget);
  });

  for (final level in ['beginner', 'intermediate', 'advanced', 'competitive']) {
    testWidgets('se renderiza para nivel $level', (tester) async {
      await pumpCharts(tester, buildHistory(4),
          profile: UserProfile(age: 40, level: level, useMockData: false));
      expect(tester.takeException(), isNull);
      expect(find.text('Índice de Eficiencia'), findsOneWidget);
    });
  }
}
