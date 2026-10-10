import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';

void main() {
  group('SwimSession', () {
    test('toJson/fromJson round-trip conserva todos los campos', () {
      final start = DateTime(2026, 1, 1, 10, 0, 0);
      final end = start.add(const Duration(minutes: 30));
      final original = SwimSession(
        id: 's1',
        startTime: start,
        endTime: end,
        distance: 1500,
        calories: 400,
        averageHeartRate: 130,
        maxHeartRate: 160,
        heartRateSeries: [HeartRatePoint(time: start, bpm: 120)],
        spo2: 97,
        waterTemperature: 27,
        averageSpeed: 1.2,
        activityType: 'POOL_SWIMMING',
        laps: [LapData(startTime: start, endTime: end, lengthMeters: 25)],
        segments: [SegmentData(startTime: start, endTime: end, segmentType: 1, repetitions: 4)],
        speedSeries: [SpeedPoint(time: start, metersPerSecond: 1.1)],
        spo2Series: [SpO2Point(time: start, percentage: 96)],
        calorieSeries: [CaloriePoint(startTime: start, endTime: end, kcal: 50)],
        stepSeries: [StepPoint(startTime: start, endTime: end, count: 30)],
      );

      final restored = SwimSession.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.distance, original.distance);
      expect(restored.calories, original.calories);
      expect(restored.averageHeartRate, original.averageHeartRate);
      expect(restored.maxHeartRate, original.maxHeartRate);
      expect(restored.spo2, original.spo2);
      expect(restored.waterTemperature, original.waterTemperature);
      expect(restored.averageSpeed, original.averageSpeed);
      expect(restored.activityType, original.activityType);
      expect(restored.heartRateSeries.single.bpm, 120);
      expect(restored.laps.single.lengthMeters, 25);
      expect(restored.segments.single.repetitions, 4);
      expect(restored.speedSeries.single.metersPerSecond, 1.1);
      expect(restored.spo2Series.single.percentage, 96);
      expect(restored.calorieSeries.single.kcal, 50);
      expect(restored.stepSeries.single.count, 30);
    });

    test('fromJson tolera listas ausentes (sesiones guardadas antes de agregar un campo)', () {
      final json = {
        'id': 's2',
        'startTime': DateTime(2026, 1, 1).toIso8601String(),
        'endTime': DateTime(2026, 1, 1, 0, 10).toIso8601String(),
        'distance': 500.0,
        'calories': 100.0,
        'heartRateSeries': [],
      };
      final session = SwimSession.fromJson(json);
      expect(session.laps, isEmpty);
      expect(session.calorieSeries, isEmpty);
      expect(session.stepSeries, isEmpty);
      expect(session.averageHeartRate, null);
    });

    test('duration se calcula a partir de start/end', () {
      final start = DateTime(2026, 1, 1, 10, 0, 0);
      final session = SwimSession(
        id: 's3',
        startTime: start,
        endTime: start.add(const Duration(minutes: 45)),
        distance: 2000,
        calories: 300,
        heartRateSeries: const [],
      );
      expect(session.duration, const Duration(minutes: 45));
    });

    test('metersPerMinute es 0 si la duración es 0', () {
      final start = DateTime(2026, 1, 1);
      final session = SwimSession(
        id: 's4',
        startTime: start,
        endTime: start,
        distance: 100,
        calories: 10,
        heartRateSeries: const [],
      );
      expect(session.metersPerMinute, 0);
    });

    test('metersPerMinute calcula correctamente con duración real', () {
      final start = DateTime(2026, 1, 1);
      final session = SwimSession(
        id: 's5',
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        distance: 500,
        calories: 10,
        heartRateSeries: const [],
      );
      expect(session.metersPerMinute, 50);
    });

    test('paceSecondsPer100m es 0 si no hay distancia', () {
      final start = DateTime(2026, 1, 1);
      final session = SwimSession(
        id: 's6',
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        distance: 0,
        calories: 0,
        heartRateSeries: const [],
      );
      expect(session.paceSecondsPer100m, 0);
      expect(session.paceString, "--:--");
    });

    test('paceString formatea minutos:segundos por cada 100m', () {
      final start = DateTime(2026, 1, 1);
      // 500m en 10 minutos (600s) -> 120s por cada 100m -> "2:00 min/100m"
      final session = SwimSession(
        id: 's7',
        startTime: start,
        endTime: start.add(const Duration(minutes: 10)),
        distance: 500,
        calories: 0,
        heartRateSeries: const [],
      );
      expect(session.paceSecondsPer100m, 120);
      expect(session.paceString, "2:00 min/100m");
    });
  });

  group('Puntos de serie (toJson/fromJson)', () {
    test('HeartRatePoint', () {
      final p = HeartRatePoint(time: DateTime(2026, 1, 1), bpm: 140);
      final restored = HeartRatePoint.fromJson(p.toJson());
      expect(restored.bpm, 140);
      expect(restored.time, p.time);
    });

    test('SpeedPoint', () {
      final p = SpeedPoint(time: DateTime(2026, 1, 1), metersPerSecond: 1.35);
      final restored = SpeedPoint.fromJson(p.toJson());
      expect(restored.metersPerSecond, 1.35);
    });

    test('SpO2Point', () {
      final p = SpO2Point(time: DateTime(2026, 1, 1), percentage: 95.5);
      final restored = SpO2Point.fromJson(p.toJson());
      expect(restored.percentage, 95.5);
    });

    test('CaloriePoint', () {
      final p = CaloriePoint(
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 30),
        kcal: 75.2,
      );
      final restored = CaloriePoint.fromJson(p.toJson());
      expect(restored.kcal, 75.2);
      expect(restored.endTime.difference(restored.startTime), const Duration(minutes: 30));
    });

    test('StepPoint', () {
      final p = StepPoint(
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 5),
        count: 42,
      );
      final restored = StepPoint.fromJson(p.toJson());
      expect(restored.count, 42);
    });

    test('LapData', () {
      final p = LapData(
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 1),
        lengthMeters: 25,
      );
      final restored = LapData.fromJson(p.toJson());
      expect(restored.lengthMeters, 25);
    });

    test('SegmentData', () {
      final p = SegmentData(
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 2),
        segmentType: 3,
        repetitions: 8,
      );
      final restored = SegmentData.fromJson(p.toJson());
      expect(restored.segmentType, 3);
      expect(restored.repetitions, 8);
    });
  });
}
