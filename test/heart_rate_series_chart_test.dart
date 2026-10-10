import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/widgets/charts/heart_rate_series_chart.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: SizedBox(height: 200, child: child)));

  testWidgets('muestra mensaje vacío si la sesión es null', (tester) async {
    await tester.pumpWidget(wrap(const HeartRateSeriesChart(session: null, age: 30)));
    expect(find.text('Sin serie de FC registrada'), findsOneWidget);
  });

  testWidgets('muestra mensaje vacío si no hay muestras de FC', (tester) async {
    final session = SwimSession(
      id: 'x',
      startTime: DateTime(2026, 1, 1),
      endTime: DateTime(2026, 1, 1, 0, 10),
      distance: 0,
      calories: 0,
      heartRateSeries: const [],
    );
    await tester.pumpWidget(wrap(HeartRateSeriesChart(session: session, age: 30)));
    expect(find.text('Sin serie de FC registrada'), findsOneWidget);
  });

  testWidgets('dibuja el chart cuando hay serie de FC', (tester) async {
    final start = DateTime(2026, 1, 1);
    final session = SwimSession(
      id: 'x',
      startTime: start,
      endTime: start.add(const Duration(minutes: 5)),
      distance: 0,
      calories: 0,
      heartRateSeries: [
        HeartRatePoint(time: start, bpm: 110),
        HeartRatePoint(time: start.add(const Duration(minutes: 5)), bpm: 150),
      ],
    );
    await tester.pumpWidget(wrap(HeartRateSeriesChart(session: session, age: 30)));
    expect(find.text('Sin serie de FC registrada'), findsNothing);
  });

  testWidgets('no revienta con edades extremas (FC máxima muy baja o alta)', (tester) async {
    final start = DateTime(2026, 1, 1);
    final session = SwimSession(
      id: 'x',
      startTime: start,
      endTime: start.add(const Duration(minutes: 1)),
      distance: 0,
      calories: 0,
      heartRateSeries: [HeartRatePoint(time: start, bpm: 100)],
    );
    await tester.pumpWidget(wrap(HeartRateSeriesChart(session: session, age: 5)));
    await tester.pumpWidget(wrap(HeartRateSeriesChart(session: session, age: 95)));
    expect(tester.takeException(), isNull);
  });
}
