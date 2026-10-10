import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/utils/splits_calculator.dart';

import '../helpers/fixtures.dart';

SwimSession _speedSession(List<(int, double)> points, {List<HeartRatePoint> hr = const []}) {
  return SwimSession(
    id: 'sp',
    startTime: kStart,
    endTime: kStart.add(Duration(seconds: points.last.$1)),
    distance: 0,
    calories: 0,
    heartRateSeries: hr,
    speedSeries: [
      for (final p in points)
        SpeedPoint(time: kStart.add(Duration(seconds: p.$1)), metersPerSecond: p.$2),
    ],
  );
}

void main() {
  group('computeSplits', () {
    test('un solo punto de velocidad no alcanza', () {
      expect(computeSplits(_speedSession([(0, 1.0)]), age: 20, level: 'beginner'), isEmpty);
    });

    test('400 m a 1 m/s dan 4 splits de 100 m', () {
      final splits = computeSplits(_speedSession([(0, 1.0), (400, 1.0)]), age: 20, level: 'beginner');
      expect(splits.map((s) => s.markMeters), [100, 200, 300, 400]);
      for (final s in splits) {
        expect(s.splitDuration, const Duration(seconds: 100));
        expect(s.paceSecondsPer100m, 100);
      }
    });

    test('el tiempo acumulado crece de a un split', () {
      final splits = computeSplits(_speedSession([(0, 2.0), (200, 2.0)]), age: 20, level: 'beginner');
      expect(splits.map((s) => s.cumulativeDuration.inSeconds), [50, 100, 150, 200]);
    });

    test('splits de 50 m', () {
      final splits = computeSplits(_speedSession([(0, 1.0), (200, 1.0)]),
          splitMeters: 50, age: 20, level: 'beginner');
      expect(splits.length, 4);
      expect(splits.first.markMeters, 50);
      // ritmo siempre expresado por 100 m: 50 s cada 50 m → 100 s/100m.
      expect(splits.first.paceSecondsPer100m, 100);
    });

    test('la distancia que sobra al final no genera split incompleto', () {
      final splits = computeSplits(_speedSession([(0, 1.0), (250, 1.0)]), age: 20, level: 'beginner');
      expect(splits.length, 2);
    });

    test('integra con trapecios cuando la velocidad cambia', () {
      // de 0 a 2 m/s en 100 s → 100 m recorridos justo al final.
      final splits = computeSplits(_speedSession([(0, 0.0), (100, 2.0)]), age: 20, level: 'beginner');
      expect(splits.single.markMeters, 100);
      expect(splits.single.splitDuration.inSeconds, 100);
    });

    test('una muestra con tiempo repetido no suma un intervalo propio', () {
      // (0,1)→(0,5) tiene dt 0 y se salta; (0,5)→(100,1) promedia 3 m/s → 300 m.
      final splits = computeSplits(
        _speedSession([(0, 1.0), (0, 5.0), (100, 1.0)]),
        age: 20,
        level: 'beginner',
      );
      expect(splits.length, 3);
      expect(splits.first.splitDuration.inSeconds, 33);
    });

    test('sin FC el promedio y el índice quedan nulos', () {
      final splits = computeSplits(_speedSession([(0, 1.0), (100, 1.0)]), age: 20, level: 'beginner');
      expect(splits.single.avgHeartRate, isNull);
      expect(splits.single.efficiencyScore, isNull);
    });

    test('con FC calcula promedio por ventana e índice', () {
      final hr = [
        HeartRatePoint(time: kStart.add(const Duration(seconds: 10)), bpm: 140),
        HeartRatePoint(time: kStart.add(const Duration(seconds: 90)), bpm: 160),
        HeartRatePoint(time: kStart.add(const Duration(seconds: 150)), bpm: 100),
      ];
      final splits = computeSplits(_speedSession([(0, 1.0), (200, 1.0)], hr: hr),
          age: 20, level: 'beginner');
      expect(splits[0].avgHeartRate, 150);
      expect(splits[1].avgHeartRate, 100);
      expect(splits[0].efficiencyScore, isNotNull);
    });

    test('ventana sin muestras de FC deja ese split sin promedio', () {
      final hr = [HeartRatePoint(time: kStart.add(const Duration(seconds: 50)), bpm: 140)];
      final splits = computeSplits(_speedSession([(0, 1.0), (200, 1.0)], hr: hr),
          age: 20, level: 'beginner');
      expect(splits[0].avgHeartRate, 140);
      expect(splits[1].avgHeartRate, isNull);
    });

    test('un nivel más exigente baja el índice del mismo split', () {
      final hr = [HeartRatePoint(time: kStart.add(const Duration(seconds: 50)), bpm: 150)];
      final session = _speedSession([(0, 1.0), (100, 1.0)], hr: hr);
      final beginner = computeSplits(session, age: 20, level: 'beginner').single.efficiencyScore!;
      final competitive = computeSplits(session, age: 20, level: 'competitive').single.efficiencyScore!;
      expect(competitive, lessThan(beginner));
    });

    test('funciona con la sesión de fixtures (1 m/s durante 20 min)', () {
      final splits = computeSplits(buildSession(), age: 30, level: 'intermediate');
      expect(splits.length, 12);
      expect(splits.last.markMeters, 1200);
    });
  });
}
