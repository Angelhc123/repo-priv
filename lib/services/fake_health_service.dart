import 'dart:convert';
import 'dart:math';
import '../models/swim_session.dart';
import '../models/user_profile.dart';

/// Simulador de datos de Health Connect — SOLO para probar la UI en el
/// escritorio (Linux/web) sin depender del teléfono ni de Mi Fitness.
///
/// Se activa con `flutter run -d linux --dart-define=FAKE_HEALTH=true`
/// (ver el guard en app_state.dart, buscar "FAKE_HEALTH"). Por defecto está
/// apagado: una build/run normal nunca pasa por acá.
///
/// Para sacar el simulador del proyecto una vez que el sistema esté listo:
/// borrar este archivo + las líneas marcadas "FAKE_HEALTH" en app_state.dart.
/// No toca health_service.dart, los modelos, ni ninguna pantalla.
class FakeHealthService {
  static final FakeHealthService _instance = FakeHealthService._internal();
  factory FakeHealthService() => _instance;
  FakeHealthService._internal();

  List<SwimSession>? _cache;

  Future<bool> requestPermissions() async => true;
  Future<bool> hasPermissions() async => true;
  Future<void> installHealthConnect() async {}

  Future<List<SwimSession>> fetchSwimSessions(UserProfile profile,
      {Duration days = const Duration(days: 1000)}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final cutoff = DateTime.now().subtract(days);
    return _allSessions(profile)
        .where((s) => s.startTime.isAfter(cutoff))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchRawHealthData(
      {Duration days = const Duration(days: 1000)}) async {
    final cutoff = DateTime.now().subtract(days);
    final sessions =
        _allSessions(UserProfile.defaultProfile()).where((s) => s.startTime.isAfter(cutoff));
    final points = sessions
        .map((s) => {
              'type': 'WORKOUT',
              'dateFrom': s.startTime.toIso8601String(),
              'dateFromEpochMs': s.startTime.millisecondsSinceEpoch,
              'dateTo': s.endTime.toIso8601String(),
              'dateToEpochMs': s.endTime.millisecondsSinceEpoch,
              'durationSeconds': s.duration.inSeconds,
              'sourceName': 'Simulador (sin dispositivo)',
              'value': {
                'kind': 'WorkoutHealthValue',
                'totalDistance': s.distance,
                'totalEnergyBurned': s.calories,
              },
            })
        .toList();
    points.sort((a, b) =>
        (b['dateFromEpochMs'] as int).compareTo(a['dateFromEpochMs'] as int));
    return points;
  }

  /// Versión simulada de exportFullDumpJson (ver health_service.dart) para
  /// poder probar el botón de export en el escritorio (FAKE_HEALTH) sin
  /// depender del canal nativo, que no existe fuera de Android.
  Future<String> exportFullDumpJson(
      {Duration days = const Duration(days: 1000)}) async {
    final cutoff = DateTime.now().subtract(days);
    final sessions =
        _allSessions(UserProfile.defaultProfile()).where((s) => s.startTime.isAfter(cutoff));

    final root = {
      'generatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'note': 'FAKE_HEALTH — datos simulados, no vienen de Health Connect',
      'sessions': sessions
          .map((s) => {
                'id': s.id,
                'startMs': s.startTime.millisecondsSinceEpoch,
                'endMs': s.endTime.millisecondsSinceEpoch,
                'exerciseTypeName': s.activityType,
                'heartRate': {
                  'status': 'ok',
                  'samples': s.heartRateSeries
                      .map((p) => {'timeMs': p.time.millisecondsSinceEpoch, 'bpm': p.bpm})
                      .toList(),
                },
                'speed': {
                  'status': 'ok',
                  'samples': s.speedSeries
                      .map((p) => {
                            'timeMs': p.time.millisecondsSinceEpoch,
                            'metersPerSecond': p.metersPerSecond,
                          })
                      .toList(),
                },
                'spo2': {
                  'status': 'ok',
                  'samples': s.spo2Series
                      .map((p) => {
                            'timeMs': p.time.millisecondsSinceEpoch,
                            'percentage': p.percentage,
                          })
                      .toList(),
                },
                'distance': {
                  'status': 'ok',
                  'totalMeters': s.distance,
                },
              })
          .toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(root);
  }

  List<SwimSession> _allSessions(UserProfile profile) {
    return _cache ??= _generateSessions(profile);
  }

  // Semilla fija → mismos datos en cada corrida, para que un gráfico raro no
  // sea "ruido del random" sino algo reproducible que se pueda debuggear.
  List<SwimSession> _generateSessions(UserProfile profile) {
    final rnd = Random(20261005);
    final sessions = <SwimSession>[];
    final now = DateTime.now();

    // Pace base por nivel declarado (seg/100m), con algo de margen por sesión.
    const basePaceByLevel = {
      'beginner': 150.0,
      'intermediate': 105.0,
      'advanced': 85.0,
      'competitive': 70.0,
    };
    final basePace = basePaceByLevel[profile.level] ?? 120.0;

    const sessionCount = 18;
    var cursor = now.subtract(const Duration(days: 58));

    for (var i = 0; i < sessionCount; i++) {
      cursor = cursor.add(Duration(days: 2 + rnd.nextInt(4), hours: rnd.nextInt(10)));
      if (cursor.isAfter(now)) break;

      final improvement = (i / sessionCount) * 10; // mejora leve con el tiempo
      final paceSecPer100m = (basePace - improvement + rnd.nextDouble() * 10)
          .clamp(50.0, 220.0);
      final totalMeters = (800 + rnd.nextInt(1700)).toDouble();
      final totalSeconds = (totalMeters / 100.0) * paceSecPer100m;
      final start = DateTime(
          cursor.year, cursor.month, cursor.day, 7 + rnd.nextInt(13), rnd.nextInt(60));
      final end = start.add(Duration(seconds: totalSeconds.round()));

      final baseHr = 108 + rnd.nextInt(18);
      final hrBoost = 28 + rnd.nextInt(18);
      final avgSpeedMs = totalMeters / totalSeconds;

      final hrSeries = <HeartRatePoint>[];
      final speedSeries = <SpeedPoint>[];
      final spo2Series = <SpO2Point>[];

      const stepSeconds = 10;
      final totalSteps = (totalSeconds / stepSeconds).ceil();
      for (var t = 0; t <= totalSteps; t++) {
        final time = start.add(const Duration(seconds: stepSeconds) * t);
        if (time.isAfter(end)) break;
        final frac = totalSteps == 0 ? 0.0 : t / totalSteps;
        // Rampa de entrada en calor, meseta de esfuerzo, caída leve al final.
        final effort = frac < 0.1
            ? frac / 0.1
            : (frac > 0.85 ? 1.0 - (frac - 0.85) / 0.15 * 0.3 : 1.0);
        final wave = sin(t * 0.6) * 3;
        final noise = (rnd.nextDouble() - 0.5);

        final hr = (baseHr + effort * hrBoost + wave + noise * 4).clamp(80.0, 190.0);
        hrSeries.add(HeartRatePoint(time: time, bpm: hr.round()));

        final speed =
            (avgSpeedMs * (0.85 + effort * 0.3) + wave * 0.01 + noise * 0.1)
                .clamp(0.3, 2.2);
        speedSeries.add(SpeedPoint(time: time, metersPerSecond: speed));

        if (t % 12 == 0) {
          final spo2 = (95 + rnd.nextDouble() * 4).clamp(90.0, 100.0);
          spo2Series.add(SpO2Point(time: time, percentage: spo2));
        }
      }

      final avgHr = hrSeries.isEmpty
          ? null
          : hrSeries.map((e) => e.bpm).reduce((a, b) => a + b) / hrSeries.length;
      final maxHr = hrSeries.isEmpty
          ? null
          : hrSeries.map((e) => e.bpm).reduce((a, b) => a > b ? a : b).toDouble();
      final avgSpeed = speedSeries.isEmpty
          ? null
          : speedSeries.map((e) => e.metersPerSecond).reduce((a, b) => a + b) /
              speedSeries.length;
      final avgSpo2 = spo2Series.isEmpty
          ? null
          : spo2Series.map((e) => e.percentage).reduce((a, b) => a + b) /
              spo2Series.length;

      sessions.add(SwimSession(
        id: 'fake-${start.millisecondsSinceEpoch}',
        startTime: start,
        endTime: end,
        distance: totalMeters,
        calories: totalMeters * 0.09 + totalSeconds / 60 * 1.5,
        averageHeartRate: avgHr,
        maxHeartRate: maxHr,
        heartRateSeries: hrSeries,
        spo2: avgSpo2,
        waterTemperature: 26 + rnd.nextDouble() * 2,
        averageSpeed: avgSpeed,
        activityType: 'SWIMMING_POOL',
        // Mi Fitness tampoco manda ExerciseLap/ExerciseSegment reales (ver
        // health_service.dart) — los dejamos vacíos para simular lo mismo
        // que pasa en producción: los splits salen de speedSeries.
        laps: const [],
        segments: const [],
        speedSeries: speedSeries,
        spo2Series: spo2Series,
      ));
    }

    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }
}
