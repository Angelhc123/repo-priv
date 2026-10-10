import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/utils/splits_calculator.dart';

SwimSession _sessionWithSpeed(List<(int secondsFromStart, double metersPerSecond)> points) {
  final start = DateTime(2026, 1, 1, 10, 0, 0);
  final series = points
      .map((p) => SpeedPoint(time: start.add(Duration(seconds: p.$1)), metersPerSecond: p.$2))
      .toList();
  return SwimSession(
    id: 'splits-test',
    startTime: start,
    endTime: start.add(Duration(seconds: points.last.$1)),
    distance: 0,
    calories: 0,
    heartRateSeries: const [],
    speedSeries: series,
  );
}

void main() {
  group('computeSplits', () {
    test('sin serie de velocidad, devuelve lista vacía', () {
      final session = _sessionWithSpeed([(0, 1.0)]); // 1 sola muestra
      final splits = computeSplits(session, age: 25, level: 'beginner');
      expect(splits, isEmpty);
    });

    test('si la distancia total integrada no llega a 100m, devuelve vacío', () {
      // 1 m/s constante durante 50s = 50m < 100m
      final session = _sessionWithSpeed([(0, 1.0), (50, 1.0)]);
      final splits = computeSplits(session, age: 25, level: 'beginner');
      expect(splits, isEmpty);
    });

    test('con velocidad constante de 1 m/s, el split de 100m tarda 100s', () {
      final session = _sessionWithSpeed([(0, 1.0), (200, 1.0)]);
      final splits = computeSplits(session, age: 25, level: 'beginner');
      expect(splits.length, 2); // 200m -> 2 splits de 100m
      expect(splits[0].markMeters, 100);
      expect(splits[0].splitDuration, const Duration(seconds: 100));
      expect(splits[0].paceSecondsPer100m, closeTo(100, 0.01));
    });

    test('incluye la FC promedio de la ventana del split, si hay serie de FC', () {
      final start = DateTime(2026, 1, 1, 10, 0, 0);
      final session = SwimSession(
        id: 'splits-hr',
        startTime: start,
        endTime: start.add(const Duration(seconds: 100)),
        distance: 0,
        calories: 0,
        heartRateSeries: [
          HeartRatePoint(time: start, bpm: 120),
          HeartRatePoint(time: start.add(const Duration(seconds: 100)), bpm: 140),
        ],
        speedSeries: [
          SpeedPoint(time: start, metersPerSecond: 1.0),
          SpeedPoint(time: start.add(const Duration(seconds: 100)), metersPerSecond: 1.0),
        ],
      );
      final splits = computeSplits(session, age: 25, level: 'beginner');
      expect(splits.single.avgHeartRate, 130);
    });
  });
}
