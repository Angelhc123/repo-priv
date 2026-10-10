import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/widgets/charts/heart_rate_series_chart.dart';

import '../helpers/fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget chart) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 300, child: chart))),
    );

void main() {
  testWidgets('sin sesión muestra el estado vacío', (tester) async {
    await _pump(tester, const HeartRateSeriesChart(session: null, age: 30));
    expect(find.text('Sin serie de FC registrada'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('sesión sin FC muestra el estado vacío', (tester) async {
    await _pump(tester, HeartRateSeriesChart(session: bareSession(), age: 30));
    expect(find.text('Sin serie de FC registrada'), findsOneWidget);
  });

  testWidgets('con FC dibuja un punto por muestra en minutos', (tester) async {
    final session = buildSession(durationSeconds: 120, stepSeconds: 30);
    await _pump(tester, HeartRateSeriesChart(session: session, age: 30));
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final spots = chart.data.lineBarsData.single.spots;
    expect(spots.map((s) => s.x), [0, 0.5, 1, 1.5, 2]);
    expect(spots.first.y, session.heartRateSeries.first.bpm.toDouble());
  });

  testWidgets('dibuja las 5 bandas de zonas según la edad', (tester) async {
    await _pump(tester, HeartRateSeriesChart(session: buildSession(), age: 20));
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final bands = chart.data.rangeAnnotations.horizontalRangeAnnotations;
    expect(bands, hasLength(5));
    expect(bands.first.y1, 100); // 50% de 200
    expect(bands.last.y1, 180); // 90% de 200
  });

  for (final (age, maxY) in const [(20, 210.0), (60, 170.0), (90, 150.0), (0, 230.0)]) {
    testWidgets('edad $age → eje Y hasta $maxY', (tester) async {
      await _pump(tester, HeartRateSeriesChart(session: buildSession(), age: age));
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.maxY, maxY);
      expect(chart.data.minY, 50);
    });
  }

  testWidgets('renderiza las etiquetas de los ejes', (tester) async {
    await _pump(tester, HeartRateSeriesChart(session: buildSession(), age: 30));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^\d+\.\dm$')), findsWidgets);
  });
}
