import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import '../models/swim_session.dart';
import '../models/user_profile.dart';

// Re-export so callers don't need to import swim_session separately
export '../models/swim_session.dart'
    show LapData, SegmentData, SpeedPoint, SpO2Point, CaloriePoint, StepPoint;

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal([Health? health]) : _health = health ?? Health();

  /// Instancia aparte (no el singleton) con un `Health` inyectado — solo
  /// para tests del fallback que usa el paquete health.
  @visibleForTesting
  factory HealthService.forTesting(Health health) =>
      HealthService._internal(health);

  final Health _health;

  // Native Android channel — queries Health Connect ExerciseSession directly,
  // bypassing the health Flutter package which fails silently for WORKOUT.
  static const _channel = MethodChannel('com.example.coswim/health_direct');

  final List<HealthDataType> _dataTypes = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WORKOUT,
  ];

  Future<bool> requestPermissions() async {
    // 1️⃣ Native Health Connect permission request — the health package's
    // requestAuthorization() throws "Unsupported operation: Google Health
    // Connect is not available" on this device even though HC works fine
    // (confirmed via the native read channel above). If this call completes
    // at all (granted or denied), trust its result and don't fall through.
    try {
      final granted =
          await _channel.invokeMethod<bool>('requestHealthPermissions');
      if (granted != null) return granted;
    } catch (e) {
      // ignore: avoid_print
      print("Native requestHealthPermissions failed: $e");
    }

    // 2️⃣ Fallback: health Flutter package (only reached if the native call
    // itself errored, e.g. a stale build without the new channel method).
    try {
      await _health.configure();
      return await _health.requestAuthorization(_dataTypes);
    } catch (e) {
      // ignore: avoid_print
      print("requestAuthorization failed: $e");
      return false;
    }
  }

  /// Checks current Health Connect grant status without prompting the user.
  Future<bool> hasPermissions() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('hasHealthPermissions');
      if (granted != null) return granted;
    } catch (e) {
      // ignore: avoid_print
      print("Native hasHealthPermissions failed: $e");
    }
    return false;
  }

  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      // ignore: avoid_print
      print("installHealthConnect failed: $e");
      rethrow;
    }
  }

  // ── FETCH SESSIONS ──────────────────────────────────────────────────────

  Future<List<SwimSession>> fetchSwimSessions(UserProfile profile,
      {Duration days = const Duration(days: 1000)}) async {
    final now = DateTime.now();
    final startMs = now.subtract(days).millisecondsSinceEpoch;
    final endMs = now.add(const Duration(minutes: 15)).millisecondsSinceEpoch;

    // 1️⃣ Try native Android channel — reads ExerciseSession directly from HC SDK
    try {
      final raw = await _channel.invokeMethod<String>(
        'getExerciseSessions',
        {'startMs': startMs, 'endMs': endMs},
      );
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        if (list.isNotEmpty) {
          // ignore: avoid_print
          print("Native HC: ${list.length} exercise sessions found");
          return _parseNativeSessions(list);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print("Native channel error: $e");
    }

    // 2️⃣ Fallback: health Flutter package (covers WORKOUT if package works)
    try {
      final dataPoints = await _fetchAllPoints(
        startTime: DateTime.fromMillisecondsSinceEpoch(startMs),
        endTime: DateTime.fromMillisecondsSinceEpoch(endMs),
      );
      final workouts =
          dataPoints.where((p) => p.type == HealthDataType.WORKOUT).toList();
      if (workouts.isNotEmpty) {
        return _buildSessionsFromPoints(workouts, dataPoints);
      }
    } catch (e) {
      // ignore: avoid_print
      print("Health package fallback error: $e");
    }

    return [];
  }

  // ── NATIVE SESSION PARSER ───────────────────────────────────────────────

  List<SwimSession> _parseNativeSessions(List<dynamic> list) {
    final sessions = <SwimSession>[];
    for (final item in list) {
      final m = item as Map<String, dynamic>;
      final start =
          DateTime.fromMillisecondsSinceEpoch(m['startMs'] as int);
      final end = DateTime.fromMillisecondsSinceEpoch(m['endMs'] as int);

      // HR series
      final hrRaw = m['heartRate'] as List<dynamic>? ?? [];
      final hrData = hrRaw.map((h) {
        final hm = h as Map<String, dynamic>;
        return HeartRatePoint(
          time: DateTime.fromMillisecondsSinceEpoch(hm['timeMs'] as int),
          bpm: hm['bpm'] as int,
        );
      }).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      final spo2Data = _parseSpO2(m['spo2'] as List<dynamic>? ?? []);
      final speedData = _parseSpeed(m['speed'] as List<dynamic>? ?? []);
      final calorieData = _parseCalories(m['calorieIntervals'] as List<dynamic>? ?? []);
      final stepData = _parseSteps(m['stepIntervals'] as List<dynamic>? ?? []);

      sessions.add(SwimSession(
        id: m['id'] as String? ?? '${start.millisecondsSinceEpoch}',
        startTime: start,
        endTime: end,
        distance: (m['totalDistanceMeters'] as num?)?.toDouble() ?? 0.0,
        calories: (m['totalCaloriesKcal'] as num?)?.toDouble() ?? 0.0,
        averageHeartRate: _calculateAverage(hrData),
        maxHeartRate: _calculateMax(hrData),
        heartRateSeries: hrData,
        spo2: _averageSpO2(spo2Data),
        waterTemperature: null,
        averageSpeed: _averageSpeed(speedData),
        activityType: _exerciseTypeName(m['exerciseType'] as int? ?? 0),
        laps: _parseLaps(m['laps'] as List<dynamic>? ?? []),
        segments: _parseSegments(m['segments'] as List<dynamic>? ?? []),
        speedSeries: speedData,
        spo2Series: spo2Data,
        calorieSeries: calorieData,
        stepSeries: stepData,
      ));
    }
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  List<LapData> _parseLaps(List<dynamic> raw) => raw.map((l) {
        final m = l as Map<String, dynamic>;
        return LapData(
          startTime: DateTime.fromMillisecondsSinceEpoch(m['startMs'] as int),
          endTime: DateTime.fromMillisecondsSinceEpoch(m['endMs'] as int),
          lengthMeters: (m['lengthMeters'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();

  List<SpeedPoint> _parseSpeed(List<dynamic> raw) => raw.map((s) {
        final m = s as Map<String, dynamic>;
        return SpeedPoint(
          time: DateTime.fromMillisecondsSinceEpoch(m['timeMs'] as int),
          metersPerSecond: (m['metersPerSecond'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  List<SpO2Point> _parseSpO2(List<dynamic> raw) => raw.map((s) {
        final m = s as Map<String, dynamic>;
        return SpO2Point(
          time: DateTime.fromMillisecondsSinceEpoch(m['timeMs'] as int),
          percentage: (m['percentage'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  List<CaloriePoint> _parseCalories(List<dynamic> raw) => raw.map((c) {
        final m = c as Map<String, dynamic>;
        return CaloriePoint(
          startTime: DateTime.fromMillisecondsSinceEpoch(m['startMs'] as int),
          endTime: DateTime.fromMillisecondsSinceEpoch(m['endMs'] as int),
          kcal: (m['kcal'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  List<StepPoint> _parseSteps(List<dynamic> raw) => raw.map((s) {
        final m = s as Map<String, dynamic>;
        return StepPoint(
          startTime: DateTime.fromMillisecondsSinceEpoch(m['startMs'] as int),
          endTime: DateTime.fromMillisecondsSinceEpoch(m['endMs'] as int),
          count: m['count'] as int? ?? 0,
        );
      }).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  double? _averageSpO2(List<SpO2Point> pts) {
    if (pts.isEmpty) return null;
    return pts.map((e) => e.percentage).reduce((a, b) => a + b) / pts.length;
  }

  double? _averageSpeed(List<SpeedPoint> pts) {
    if (pts.isEmpty) return null;
    return pts.map((e) => e.metersPerSecond).reduce((a, b) => a + b) / pts.length;
  }

  List<SegmentData> _parseSegments(List<dynamic> raw) => raw.map((s) {
        final m = s as Map<String, dynamic>;
        return SegmentData(
          startTime: DateTime.fromMillisecondsSinceEpoch(m['startMs'] as int),
          endTime: DateTime.fromMillisecondsSinceEpoch(m['endMs'] as int),
          segmentType: m['segmentType'] as int? ?? 0,
          repetitions: m['repetitions'] as int? ?? 0,
        );
      }).toList();

  String _exerciseTypeName(int type) {
    const names = {
      40: 'RUNNING', 41: 'RUNNING_TREADMILL',
      56: 'SWIMMING_OPEN_WATER', 57: 'SWIMMING_POOL',
      4: 'BIKING', 5: 'BIKING_STATIONARY',
      61: 'WALKING', 53: 'STRENGTH_TRAINING',
      65: 'YOGA', 21: 'HIIT', 11: 'ELLIPTICAL',
      1: 'BADMINTON', 3: 'BASKETBALL', 48: 'SOCCER',
      59: 'TENNIS', 60: 'VOLLEYBALL', 63: 'WEIGHTLIFTING',
      0: 'ENTRENAMIENTO',
    };
    return names[type] ?? 'TIPO_$type';
  }

  // ── HEALTH PACKAGE FALLBACK ─────────────────────────────────────────────

  List<SwimSession> _buildSessionsFromPoints(
      List<HealthDataPoint> workouts, List<HealthDataPoint> all) {
    return workouts.map((wp) {
      final wv = wp.value as WorkoutHealthValue?;
      final start = wp.dateFrom;
      final end = wp.dateTo;
      final hrData =
          _extractHRSeries(all, HealthDataType.HEART_RATE, start, end);
      final spo2Vals =
          _extractNumericValues(all, HealthDataType.BLOOD_OXYGEN, start, end);
      return SwimSession(
        id: '${start.millisecondsSinceEpoch}',
        startTime: start,
        endTime: end,
        distance: wv?.totalDistance?.toDouble() ??
            _extractSum(all, HealthDataType.DISTANCE_DELTA, start, end) ??
            0.0,
        calories: wv?.totalEnergyBurned?.toDouble() ??
            _extractSum(
                all, HealthDataType.ACTIVE_ENERGY_BURNED, start, end) ??
            0.0,
        averageHeartRate: _calculateAverage(hrData),
        maxHeartRate: _calculateMax(hrData),
        heartRateSeries: hrData,
        spo2: spo2Vals.isNotEmpty
            ? spo2Vals.reduce((a, b) => a + b) / spo2Vals.length
            : null,
        waterTemperature: null,
        averageSpeed: null,
        activityType: wv?.workoutActivityType
                .toString()
                .replaceAll('HealthWorkoutActivityType.', '') ??
            'ENTRENAMIENTO',
        laps: const [],
        segments: const [],
      );
    }).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  // ── VOLCADO COMPLETO DE DIAGNÓSTICO ─────────────────────────────────────

  /// Pide a Health Connect, vía el canal nativo, absolutamente todo lo que
  /// pueda dar sobre cada sesión de entrenamiento (HR, velocidad, SpO2,
  /// distancia, calorías, VO2 max, variabilidad cardíaca, temperatura de
  /// piel, potencia, pasos, etc). Cada tipo viene marcado "ok"/"no_permission"
  /// /"unsupported"/"error" — ver exportFullDump en MainActivity.kt — así que
  /// un `null` siempre significa "no se pudo leer", nunca "midió cero".
  /// Devuelve el JSON crudo (pretty-printed) listo para guardar en un .txt.
  Future<String> exportFullDumpJson({Duration days = const Duration(days: 1000)}) async {
    final now = DateTime.now();
    final startMs = now.subtract(days).millisecondsSinceEpoch;
    final endMs = now.add(const Duration(minutes: 15)).millisecondsSinceEpoch;

    final raw = await _channel.invokeMethod<String>(
      'exportFullDump',
      {'startMs': startMs, 'endMs': endMs},
    );
    return raw ?? '{"error": "El canal nativo no devolvió nada"}';
  }

  // ── RAW DATA ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchRawHealthData(
      {Duration days = const Duration(days: 1000)}) async {
    final now = DateTime.now();
    final startTime = now.subtract(days);
    final endTime = now.add(const Duration(minutes: 15));

    // 1️⃣ Native Android channel — reads Health Connect records directly via
    // the platform SDK, same as getExerciseSessions above. Bypasses the
    // health Flutter package's configure(), which can throw "Health Connect
    // not available" on this device even though HC works fine (same class
    // of bug as requestAuthorization) — that was leaving the whole
    // dashboard empty, not just the workouts section.
    try {
      final raw = await _channel.invokeMethod<String>(
        'getRawHealthPoints',
        {
          'startMs': startTime.millisecondsSinceEpoch,
          'endMs': endTime.millisecondsSinceEpoch,
        },
      );
      if (raw != null) {
        final list =
            (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
        list.sort((a, b) => (b['dateFromEpochMs'] as int)
            .compareTo(a['dateFromEpochMs'] as int));
        return list;
      }
    } catch (e) {
      // ignore: avoid_print
      print("Native raw data channel error: $e");
    }

    // 2️⃣ Fallback: health Flutter package.
    try {
      final dataPoints =
          await _fetchAllPoints(startTime: startTime, endTime: endTime);
      dataPoints.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      return dataPoints.map(_toMap).toList();
    } catch (e) {
      // ignore: avoid_print
      print("Health package raw fallback error: $e");
      return [];
    }
  }

  // ── HELPERS ─────────────────────────────────────────────────────────────

  Future<List<HealthDataPoint>> _fetchAllPoints({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    await _health.configure();
    final List<HealthDataPoint> all = [];
    for (final type in _dataTypes) {
      try {
        all.addAll(await _health.getHealthDataFromTypes(
          types: [type],
          startTime: startTime,
          endTime: endTime,
        ));
      } catch (e) {
        // ignore: avoid_print
        print("Could not fetch $type: $e");
      }
    }
    return all;
  }

  Map<String, dynamic> _toMap(HealthDataPoint p) {
    Map<String, dynamic> valueMap = {};
    final val = p.value;
    if (val is NumericHealthValue) {
      valueMap['kind'] = 'NumericHealthValue';
      valueMap['numericValue'] = val.numericValue;
    } else if (val is WorkoutHealthValue) {
      valueMap['kind'] = 'WorkoutHealthValue';
      valueMap['workoutActivityType'] = val.workoutActivityType
          .toString()
          .replaceAll('HealthWorkoutActivityType.', '');
      valueMap['totalDistance'] = val.totalDistance;
      valueMap['totalDistanceUnit'] =
          val.totalDistanceUnit?.toString().replaceAll('HealthDataUnit.', '');
      valueMap['totalEnergyBurned'] = val.totalEnergyBurned;
      valueMap['totalEnergyBurnedUnit'] = val.totalEnergyBurnedUnit
          ?.toString()
          .replaceAll('HealthDataUnit.', '');
    } else {
      valueMap['kind'] = val.runtimeType.toString();
      valueMap['rawString'] = val.toString();
    }
    return {
      'type': p.type.toString().replaceAll('HealthDataType.', ''),
      'dateFrom': p.dateFrom.toIso8601String(),
      'dateFromEpochMs': p.dateFrom.millisecondsSinceEpoch,
      'dateTo': p.dateTo.toIso8601String(),
      'dateToEpochMs': p.dateTo.millisecondsSinceEpoch,
      'durationSeconds': p.dateTo.difference(p.dateFrom).inSeconds,
      'unit': p.unit.toString().replaceAll('HealthDataUnit.', ''),
      'sourceId': p.sourceId,
      'sourceName': p.sourceName,
      'sourcePlatform':
          p.sourcePlatform.toString().replaceAll('HealthPlatform.', ''),
      'recordingMethod':
          p.recordingMethod.toString().replaceAll('RecordingMethod.', ''),
      'value': valueMap,
    };
  }

  double? _calculateAverage(List<HeartRatePoint> pts) {
    if (pts.isEmpty) return null;
    return pts.map((e) => e.bpm).reduce((a, b) => a + b) / pts.length;
  }

  double? _calculateMax(List<HeartRatePoint> pts) {
    if (pts.isEmpty) return null;
    return pts.map((e) => e.bpm).reduce((a, b) => a > b ? a : b).toDouble();
  }

  double? _extractSum(List<HealthDataPoint> pts, HealthDataType type,
      DateTime start, DateTime end) {
    final f = pts.where((p) =>
        p.type == type &&
        !p.dateFrom.isBefore(start.subtract(const Duration(seconds: 1))) &&
        !p.dateTo.isAfter(end.add(const Duration(seconds: 1))));
    if (f.isEmpty) return null;
    return f.map((p) {
      final v = p.value;
      return v is NumericHealthValue ? v.numericValue.toDouble() : 0.0;
    }).reduce((a, b) => a + b);
  }

  List<double> _extractNumericValues(List<HealthDataPoint> pts,
      HealthDataType type, DateTime start, DateTime end) {
    return pts
        .where((p) =>
            p.type == type &&
            !p.dateFrom.isBefore(start.subtract(const Duration(seconds: 1))) &&
            !p.dateTo.isAfter(end.add(const Duration(seconds: 1))))
        .map((p) {
          final v = p.value;
          return v is NumericHealthValue ? v.numericValue.toDouble() : 0.0;
        })
        .toList();
  }

  List<HeartRatePoint> _extractHRSeries(List<HealthDataPoint> pts,
      HealthDataType type, DateTime start, DateTime end) {
    return pts
        .where((p) =>
            p.type == type &&
            !p.dateFrom.isBefore(start.subtract(const Duration(seconds: 1))) &&
            !p.dateTo.isAfter(end.add(const Duration(seconds: 1))))
        .map((p) {
          final v = p.value;
          return HeartRatePoint(
            time: p.dateFrom,
            bpm: v is NumericHealthValue ? v.numericValue.toInt() : 0,
          );
        })
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }
}
