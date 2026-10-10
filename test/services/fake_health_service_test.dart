import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/services/fake_health_service.dart';

/// Tests del simulador FAKE_HEALTH (lib/services/fake_health_service.dart).
/// Es un singleton con caché, así que todas las lecturas ven los mismos datos.
void main() {
  final sim = FakeHealthService();
  final profile = UserProfile.defaultProfile();

  test('es un singleton', () {
    expect(identical(FakeHealthService(), sim), isTrue);
  });

  test('requestPermissions siempre concede', () async {
    expect(await sim.requestPermissions(), isTrue);
  });

  test('hasPermissions siempre es true', () async {
    expect(await sim.hasPermissions(), isTrue);
  });

  test('installHealthConnect no hace nada ni falla', () async {
    await sim.installHealthConnect();
  });

  group('fetchSwimSessions', () {
    test('genera sesiones simuladas', () async {
      final sessions = await sim.fetchSwimSessions(profile);
      expect(sessions, isNotEmpty);
      expect(sessions.length, lessThanOrEqualTo(18));
    });

    test('vienen de la más reciente a la más antigua', () async {
      final sessions = await sim.fetchSwimSessions(profile);
      for (var i = 1; i < sessions.length; i++) {
        expect(sessions[i - 1].startTime.isAfter(sessions[i].startTime), isTrue);
      }
    });

    test('todas son de natación en piscina con id fake-', () async {
      for (final s in await sim.fetchSwimSessions(profile)) {
        expect(s.activityType, 'SWIMMING_POOL');
        expect(s.id, startsWith('fake-'));
      }
    });

    test('cada sesión tiene series de FC, velocidad y SpO2', () async {
      for (final s in await sim.fetchSwimSessions(profile)) {
        expect(s.heartRateSeries, isNotEmpty);
        expect(s.speedSeries, isNotEmpty);
        expect(s.spo2Series, isNotEmpty);
      }
    });

    test('valores dentro de rangos fisiológicos', () async {
      for (final s in await sim.fetchSwimSessions(profile)) {
        expect(s.distance, inInclusiveRange(800, 2500));
        expect(s.averageHeartRate, inInclusiveRange(80, 190));
        expect(s.maxHeartRate! >= s.averageHeartRate!, isTrue);
        expect(s.spo2, inInclusiveRange(90, 100));
        expect(s.waterTemperature, inInclusiveRange(26, 28));
        for (final p in s.speedSeries) {
          expect(p.metersPerSecond, inInclusiveRange(0.3, 2.2));
        }
      }
    });

    test('no simula vueltas ni segmentos (igual que Mi Fitness)', () async {
      for (final s in await sim.fetchSwimSessions(profile)) {
        expect(s.laps, isEmpty);
        expect(s.segments, isEmpty);
      }
    });

    test('las series quedan dentro de la sesión', () async {
      for (final s in await sim.fetchSwimSessions(profile)) {
        expect(s.heartRateSeries.first.time, s.startTime);
        expect(s.heartRateSeries.last.time.isAfter(s.endTime), isFalse);
      }
    });

    test('filtra por rango de días', () async {
      final all = await sim.fetchSwimSessions(profile);
      final recent = await sim.fetchSwimSessions(profile, days: const Duration(days: 10));
      expect(recent.length, lessThan(all.length));
      final cutoff = DateTime.now().subtract(const Duration(days: 10));
      for (final s in recent) {
        expect(s.startTime.isAfter(cutoff), isTrue);
      }
    });

    test('rango de 0 días no devuelve nada', () async {
      expect(await sim.fetchSwimSessions(profile, days: Duration.zero), isEmpty);
    });

    test('es determinista entre llamadas', () async {
      final a = await sim.fetchSwimSessions(profile);
      final b = await sim.fetchSwimSessions(profile);
      expect(a.map((s) => s.id), b.map((s) => s.id));
    });
  });

  group('fetchRawHealthData', () {
    test('un punto WORKOUT por sesión', () async {
      final sessions = await sim.fetchSwimSessions(profile);
      final raw = await sim.fetchRawHealthData();
      expect(raw.length, sessions.length);
      expect(raw.every((p) => p['type'] == 'WORKOUT'), isTrue);
    });

    test('ordenados del más nuevo al más viejo', () async {
      final raw = await sim.fetchRawHealthData();
      for (var i = 1; i < raw.length; i++) {
        expect(raw[i - 1]['dateFromEpochMs'] as int, greaterThan(raw[i]['dateFromEpochMs'] as int));
      }
    });

    test('incluye distancia y energía del workout', () async {
      final p = (await sim.fetchRawHealthData()).first;
      expect(p['value']['kind'], 'WorkoutHealthValue');
      expect(p['value']['totalDistance'], isA<double>());
      expect(p['value']['totalEnergyBurned'], isA<double>());
      expect(p['sourceName'], contains('Simulador'));
    });

    test('respeta el rango de días', () async {
      expect(await sim.fetchRawHealthData(days: Duration.zero), isEmpty);
    });
  });

  group('exportFullDumpJson', () {
    test('es JSON válido con nota de datos simulados', () async {
      final root = jsonDecode(await sim.exportFullDumpJson()) as Map<String, dynamic>;
      expect(root['note'], contains('FAKE_HEALTH'));
      expect(root['generatedAtMs'], isA<int>());
    });

    test('cada sesión trae FC, velocidad, SpO2 y distancia con status ok', () async {
      final root = jsonDecode(await sim.exportFullDumpJson()) as Map<String, dynamic>;
      final sessions = root['sessions'] as List;
      expect(sessions, isNotEmpty);
      for (final s in sessions) {
        for (final key in ['heartRate', 'speed', 'spo2', 'distance']) {
          expect(s[key]['status'], 'ok');
        }
        expect(s['heartRate']['samples'], isNotEmpty);
        expect(s['exerciseTypeName'], 'SWIMMING_POOL');
      }
    });

    test('rango de 0 días deja la lista de sesiones vacía', () async {
      final root = jsonDecode(await sim.exportFullDumpJson(days: Duration.zero));
      expect(root['sessions'], isEmpty);
    });

    test('está indentado para leerse en un .txt', () async {
      expect(await sim.exportFullDumpJson(), contains('\n  "'));
    });
  });
}
