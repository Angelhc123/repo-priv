import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';

import '../helpers/fixtures.dart';

SwimSession _session({required int seconds, required double distance}) =>
    bareSession(durationSeconds: seconds, distance: distance);

void main() {
  group('SwimSession.paceString', () {
    // (segundos, metros, esperado)
    const cases = <(int, double, String)>[
      (120, 100, '2:00 min/100m'),
      (90, 100, '1:30 min/100m'),
      (65, 100, '1:05 min/100m'),
      (1800, 1500, '2:00 min/100m'),
      (1500, 1000, '2:30 min/100m'),
      (600, 1000, '1:00 min/100m'),
      (59, 100, '0:59 min/100m'),
      (3600, 1000, '6:00 min/100m'),
    ];
    for (final c in cases) {
      test('${c.$2.toInt()} m en ${c.$1} s → "${c.$3}"', () {
        expect(_session(seconds: c.$1, distance: c.$2).paceString, c.$3);
      });
    }

    test('distancia 0 devuelve "--:--"', () {
      expect(_session(seconds: 600, distance: 0).paceString, '--:--');
    });

    test('distancia negativa devuelve "--:--"', () {
      expect(_session(seconds: 600, distance: -50).paceString, '--:--');
    });

    test('los segundos siempre llevan dos dígitos', () {
      expect(_session(seconds: 61, distance: 100).paceString, '1:01 min/100m');
    });
  });

  group('SwimSession.paceSecondsPer100m', () {
    test('1000 m en 20 min son 120 s/100m', () {
      expect(_session(seconds: 1200, distance: 1000).paceSecondsPer100m, 120);
    });

    test('50 m en 60 s son 120 s/100m', () {
      expect(_session(seconds: 60, distance: 50).paceSecondsPer100m, 120);
    });

    test('distancia negativa devuelve 0', () {
      expect(_session(seconds: 60, distance: -1).paceSecondsPer100m, 0);
    });
  });

  group('SwimSession.metersPerMinute', () {
    test('1000 m en 20 min son 50 m/min', () {
      expect(_session(seconds: 1200, distance: 1000).metersPerMinute, 50);
    });

    test('fin anterior al inicio devuelve 0', () {
      final s = SwimSession(
        id: 'x',
        startTime: kStart,
        endTime: kStart.subtract(const Duration(minutes: 5)),
        distance: 500,
        calories: 0,
        heartRateSeries: const [],
      );
      expect(s.metersPerMinute, 0);
    });

    test('duration es negativa si el fin es anterior al inicio', () {
      final s = SwimSession(
        id: 'x',
        startTime: kStart,
        endTime: kStart.subtract(const Duration(minutes: 5)),
        distance: 500,
        calories: 0,
        heartRateSeries: const [],
      );
      expect(s.duration.isNegative, isTrue);
    });
  });

  group('SwimSession valores por defecto', () {
    final s = bareSession();

    test('laps vacío por defecto', () => expect(s.laps, isEmpty));
    test('segments vacío por defecto', () => expect(s.segments, isEmpty));
    test('speedSeries vacío por defecto', () => expect(s.speedSeries, isEmpty));
    test('spo2Series vacío por defecto', () => expect(s.spo2Series, isEmpty));
    test('calorieSeries vacío por defecto', () => expect(s.calorieSeries, isEmpty));
    test('stepSeries vacío por defecto', () => expect(s.stepSeries, isEmpty));
    test('campos opcionales nulos por defecto', () {
      expect(s.averageHeartRate, isNull);
      expect(s.maxHeartRate, isNull);
      expect(s.spo2, isNull);
      expect(s.waterTemperature, isNull);
      expect(s.averageSpeed, isNull);
      expect(s.activityType, isNull);
    });
  });

  group('SwimSession.fromJson', () {
    Map<String, dynamic> minimal() => {
          'id': 'm1',
          'startTime': '2026-01-01T10:00:00.000',
          'endTime': '2026-01-01T10:30:00.000',
          'distance': 1000,
          'calories': 200,
          'heartRateSeries': [],
        };

    test('acepta enteros en campos double', () {
      final s = SwimSession.fromJson({
        ...minimal(),
        'averageHeartRate': 130,
        'maxHeartRate': 160,
        'spo2': 97,
        'waterTemperature': 27,
        'averageSpeed': 1,
      });
      expect(s.distance, isA<double>());
      expect(s.averageHeartRate, 130.0);
      expect(s.maxHeartRate, 160.0);
      expect(s.spo2, 97.0);
      expect(s.waterTemperature, 27.0);
      expect(s.averageSpeed, 1.0);
    });

    test('campos opcionales ausentes quedan nulos', () {
      final s = SwimSession.fromJson(minimal());
      expect(s.averageHeartRate, isNull);
      expect(s.activityType, isNull);
    });

    test('listas explícitamente nulas se leen como vacías', () {
      final s = SwimSession.fromJson({
        ...minimal(),
        'laps': null,
        'segments': null,
        'speedSeries': null,
        'spo2Series': null,
        'calorieSeries': null,
        'stepSeries': null,
      });
      expect(s.laps, isEmpty);
      expect(s.stepSeries, isEmpty);
    });

    test('sin heartRateSeries lanza error (campo obligatorio)', () {
      final json = minimal()..remove('heartRateSeries');
      expect(() => SwimSession.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('fecha inválida lanza FormatException', () {
      expect(
        () => SwimSession.fromJson({...minimal(), 'startTime': 'ayer'}),
        throwsFormatException,
      );
    });

    test('round-trip de una sesión con todas las series', () {
      final original = buildSession();
      final restored = SwimSession.fromJson(original.toJson());
      expect(restored.heartRateSeries.length, original.heartRateSeries.length);
      expect(restored.speedSeries.length, original.speedSeries.length);
      expect(restored.spo2Series.length, original.spo2Series.length);
      expect(restored.calorieSeries.length, original.calorieSeries.length);
      expect(restored.stepSeries.length, original.stepSeries.length);
      expect(restored.toJson(), original.toJson());
    });
  });

  group('Puntos de serie', () {
    test('HeartRatePoint.toJson usa ISO 8601', () {
      final p = HeartRatePoint(time: kStart, bpm: 120);
      expect(p.toJson()['time'], kStart.toIso8601String());
    });

    test('SpeedPoint.fromJson acepta enteros', () {
      final p = SpeedPoint.fromJson({'time': kStart.toIso8601String(), 'metersPerSecond': 2});
      expect(p.metersPerSecond, 2.0);
    });

    test('SpO2Point.fromJson acepta enteros', () {
      final p = SpO2Point.fromJson({'time': kStart.toIso8601String(), 'percentage': 98});
      expect(p.percentage, 98.0);
    });

    test('CaloriePoint.fromJson acepta enteros', () {
      final p = CaloriePoint.fromJson({
        'startTime': kStart.toIso8601String(),
        'endTime': kStart.toIso8601String(),
        'kcal': 12,
      });
      expect(p.kcal, 12.0);
    });

    test('LapData.fromJson acepta enteros', () {
      final p = LapData.fromJson({
        'startTime': kStart.toIso8601String(),
        'endTime': kStart.toIso8601String(),
        'lengthMeters': 25,
      });
      expect(p.lengthMeters, 25.0);
    });

    test('SegmentData.toJson incluye tipo y repeticiones', () {
      final p = SegmentData(startTime: kStart, endTime: kStart, segmentType: 3, repetitions: 7);
      expect(p.toJson()['segmentType'], 3);
      expect(p.toJson()['repetitions'], 7);
    });

    test('StepPoint.toJson incluye el conteo', () {
      final p = StepPoint(startTime: kStart, endTime: kStart, count: 42);
      expect(p.toJson()['count'], 42);
    });
  });
}
