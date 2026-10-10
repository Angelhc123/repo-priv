import 'package:coswim/models/swim_session.dart';

/// Inicio fijo para que los tests no dependan de la hora en que corren.
final DateTime kStart = DateTime(2026, 1, 15, 8, 0, 0);

/// Sesión con series completas: FC cada [stepSeconds], velocidad constante
/// [speedMs] (así los splits son predecibles), SpO2, calorías y pasos.
SwimSession buildSession({
  String id = 's1',
  DateTime? start,
  int durationSeconds = 1200,
  double distance = 1000,
  double calories = 250,
  int stepSeconds = 10,
  int baseBpm = 130,
  double speedMs = 1.0,
  double? spo2 = 97,
  double? waterTemperature = 27,
  bool withHr = true,
  bool withSpeed = true,
  bool withSpo2 = true,
  bool withCalories = true,
  bool withSteps = true,
  String? activityType = 'SWIMMING_POOL',
}) {
  final s = start ?? kStart;
  final end = s.add(Duration(seconds: durationSeconds));
  final hr = <HeartRatePoint>[];
  final speed = <SpeedPoint>[];
  final spo2Series = <SpO2Point>[];
  for (var t = 0; t <= durationSeconds; t += stepSeconds) {
    final time = s.add(Duration(seconds: t));
    if (withHr) hr.add(HeartRatePoint(time: time, bpm: baseBpm + (t ~/ stepSeconds) % 10));
    if (withSpeed) speed.add(SpeedPoint(time: time, metersPerSecond: speedMs));
    if (withSpo2 && t % 120 == 0) {
      spo2Series.add(SpO2Point(time: time, percentage: 96 + (t ~/ 120) % 3));
    }
  }
  final calorieSeries = <CaloriePoint>[];
  final stepSeries = <StepPoint>[];
  for (var t = 0; t < durationSeconds; t += 300) {
    final a = s.add(Duration(seconds: t));
    final b = s.add(Duration(seconds: t + 300));
    if (withCalories) calorieSeries.add(CaloriePoint(startTime: a, endTime: b, kcal: 40 + t / 100));
    if (withSteps) stepSeries.add(StepPoint(startTime: a, endTime: b, count: 100 + t ~/ 10));
  }
  double? avg;
  double? max;
  if (hr.isNotEmpty) {
    avg = hr.map((e) => e.bpm).reduce((a, b) => a + b) / hr.length;
    max = hr.map((e) => e.bpm).reduce((a, b) => a > b ? a : b).toDouble();
  }
  return SwimSession(
    id: id,
    startTime: s,
    endTime: end,
    distance: distance,
    calories: calories,
    averageHeartRate: avg,
    maxHeartRate: max,
    heartRateSeries: hr,
    spo2: withSpo2 ? spo2 : null,
    waterTemperature: waterTemperature,
    averageSpeed: withSpeed ? speedMs : null,
    activityType: activityType,
    speedSeries: speed,
    spo2Series: spo2Series,
    calorieSeries: calorieSeries,
    stepSeries: stepSeries,
  );
}

/// Sesión mínima, sin ninguna serie.
SwimSession bareSession({
  String id = 'bare',
  DateTime? start,
  int durationSeconds = 1800,
  double distance = 1500,
  double calories = 300,
  double? averageHeartRate,
  double? maxHeartRate,
  double? spo2,
  double? waterTemperature,
  String? activityType,
}) {
  final s = start ?? kStart;
  return SwimSession(
    id: id,
    startTime: s,
    endTime: s.add(Duration(seconds: durationSeconds)),
    distance: distance,
    calories: calories,
    averageHeartRate: averageHeartRate,
    maxHeartRate: maxHeartRate,
    heartRateSeries: const [],
    spo2: spo2,
    waterTemperature: waterTemperature,
    activityType: activityType,
  );
}

/// N sesiones, la más reciente primero (como las ordena la app), separadas
/// por [gapDays] días y terminando [endDaysAgo] días antes de hoy.
List<SwimSession> buildHistory(int n, {int gapDays = 3, int endDaysAgo = 1}) {
  final now = DateTime.now();
  return List.generate(n, (i) {
    final start = DateTime(now.year, now.month, now.day, 8)
        .subtract(Duration(days: endDaysAgo + i * gapDays));
    return buildSession(
      id: 'h$i',
      start: start,
      distance: 800.0 + i * 100,
      calories: 200.0 + i * 10,
      baseBpm: 120 + (i % 5) * 5,
      speedMs: 0.9 + (i % 3) * 0.1,
    );
  });
}

/// Punto crudo con la misma forma que devuelve HealthService._toMap / el
/// canal nativo, para alimentar DashboardScreen y RawJsonScreen.
Map<String, dynamic> rawPoint(
  String type,
  DateTime from, {
  int seconds = 60,
  Object? numericValue = 1.0,
  String unit = 'METER',
  String sourceName = 'Mi Fitness',
  String sourceId = 'com.mi.health',
  Map<String, dynamic>? value,
}) {
  final to = from.add(Duration(seconds: seconds));
  return {
    'type': type,
    'dateFrom': from.toIso8601String(),
    'dateFromEpochMs': from.millisecondsSinceEpoch,
    'dateTo': to.toIso8601String(),
    'dateToEpochMs': to.millisecondsSinceEpoch,
    'durationSeconds': seconds,
    'unit': unit,
    'sourceId': sourceId,
    'sourceName': sourceName,
    'sourcePlatform': 'googleHealthConnect',
    'recordingMethod': 'automatic',
    'value': value ?? {'kind': 'NumericHealthValue', 'numericValue': numericValue},
  };
}
