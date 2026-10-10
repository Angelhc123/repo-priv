import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/services/health_service.dart';

import '../helpers/fakes.dart';

const _channel = MethodChannel('com.example.coswim/health_direct');

final _start = DateTime(2026, 3, 10, 7, 0);
int _ms(int seconds) => _start.add(Duration(seconds: seconds)).millisecondsSinceEpoch;

/// Respuesta del canal nativo por método; un valor `Exception` se lanza.
void _mockChannel(Map<String, Object?> responses, {List<MethodCall>? log}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
    log?.add(call);
    final r = responses[call.method];
    if (r is Exception) throw r;
    return r;
  });
}

Map<String, dynamic> _nativeSession({
  String? id = 'native-1',
  int startSec = 0,
  int endSec = 1800,
  int? exerciseType = 57,
  num? distance = 1500,
  num? calories = 320,
}) =>
    {
      if (id != null) 'id': id,
      'startMs': _ms(startSec),
      'endMs': _ms(endSec),
      if (exerciseType != null) 'exerciseType': exerciseType,
      if (distance != null) 'totalDistanceMeters': distance,
      if (calories != null) 'totalCaloriesKcal': calories,
      'heartRate': [
        {'timeMs': _ms(120), 'bpm': 150},
        {'timeMs': _ms(0), 'bpm': 110},
        {'timeMs': _ms(60), 'bpm': 130},
      ],
      'spo2': [
        {'timeMs': _ms(600), 'percentage': 98},
        {'timeMs': _ms(0), 'percentage': 96},
      ],
      'speed': [
        {'timeMs': _ms(60), 'metersPerSecond': 1.2},
        {'timeMs': _ms(0), 'metersPerSecond': 0.8},
      ],
      'calorieIntervals': [
        {'startMs': _ms(300), 'endMs': _ms(600), 'kcal': 40},
        {'startMs': _ms(0), 'endMs': _ms(300), 'kcal': 30.5},
      ],
      'stepIntervals': [
        {'startMs': _ms(300), 'endMs': _ms(600), 'count': 200},
        {'startMs': _ms(0), 'endMs': _ms(300)},
      ],
      'laps': [
        {'startMs': _ms(0), 'endMs': _ms(30), 'lengthMeters': 25},
        {'startMs': _ms(30), 'endMs': _ms(60)},
      ],
      'segments': [
        {'startMs': _ms(0), 'endMs': _ms(600), 'segmentType': 4, 'repetitions': 3},
        {'startMs': _ms(600), 'endMs': _ms(900)},
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('requestPermissions', () {
    test('devuelve true si el canal nativo concede', () async {
      _mockChannel({'requestHealthPermissions': true});
      expect(await HealthService.forTesting(FakeHealthPlugin()).requestPermissions(), isTrue);
    });

    test('devuelve false si el canal nativo niega, sin caer al paquete health', () async {
      final plugin = FakeHealthPlugin();
      _mockChannel({'requestHealthPermissions': false});
      expect(await HealthService.forTesting(plugin).requestPermissions(), isFalse);
      expect(plugin.configureCalls, 0);
    });

    test('si el canal nativo falla y el paquete health también, devuelve false', () async {
      final plugin = FakeHealthPlugin(configureError: Exception('HC no disponible'));
      _mockChannel({'requestHealthPermissions': PlatformException(code: 'x')});
      expect(await HealthService.forTesting(plugin).requestPermissions(), isFalse);
      expect(plugin.configureCalls, 1);
    });

    test('si el canal nativo devuelve null intenta el paquete health', () async {
      final plugin = FakeHealthPlugin(configureError: Exception('sin HC'));
      _mockChannel({'requestHealthPermissions': null});
      expect(await HealthService.forTesting(plugin).requestPermissions(), isFalse);
      expect(plugin.configureCalls, 1);
    });
  });

  group('hasPermissions', () {
    test('true si el canal nativo lo confirma', () async {
      _mockChannel({'hasHealthPermissions': true});
      expect(await HealthService.forTesting(FakeHealthPlugin()).hasPermissions(), isTrue);
    });

    test('false si el canal nativo dice que no', () async {
      _mockChannel({'hasHealthPermissions': false});
      expect(await HealthService.forTesting(FakeHealthPlugin()).hasPermissions(), isFalse);
    });

    test('false si el canal nativo devuelve null', () async {
      _mockChannel({'hasHealthPermissions': null});
      expect(await HealthService.forTesting(FakeHealthPlugin()).hasPermissions(), isFalse);
    });

    test('false si el canal nativo lanza error', () async {
      _mockChannel({'hasHealthPermissions': PlatformException(code: 'x')});
      expect(await HealthService.forTesting(FakeHealthPlugin()).hasPermissions(), isFalse);
    });
  });

  group('fetchSwimSessions (canal nativo)', () {
    late List<MethodCall> log;

    Future<List<dynamic>> fetch(List<Map<String, dynamic>> native) async {
      log = [];
      _mockChannel({'getExerciseSessions': jsonEncode(native)}, log: log);
      return HealthService.forTesting(FakeHealthPlugin())
          .fetchSwimSessions(UserProfile.defaultProfile());
    }

    test('envía el rango startMs/endMs al canal', () async {
      await fetch([_nativeSession()]);
      final args = log.single.arguments as Map;
      expect(args['startMs'], isA<int>());
      expect(args['endMs'] as int, greaterThan(args['startMs'] as int));
    });

    test('parsea id, fechas, distancia y calorías', () async {
      final s = (await fetch([_nativeSession()])).single;
      expect(s.id, 'native-1');
      expect(s.startTime, _start);
      expect(s.duration, const Duration(minutes: 30));
      expect(s.distance, 1500.0);
      expect(s.calories, 320.0);
    });

    test('ordena la serie de FC y calcula promedio y máximo', () async {
      final s = (await fetch([_nativeSession()])).single;
      expect(s.heartRateSeries.map((p) => p.bpm), [110, 130, 150]);
      expect(s.averageHeartRate, 130);
      expect(s.maxHeartRate, 150);
    });

    test('ordena SpO2 y calcula su promedio', () async {
      final s = (await fetch([_nativeSession()])).single;
      expect(s.spo2Series.map((p) => p.percentage), [96, 98]);
      expect(s.spo2, 97);
    });

    test('ordena la velocidad y calcula su promedio', () async {
      final s = (await fetch([_nativeSession()])).single;
      expect(s.speedSeries.map((p) => p.metersPerSecond), [0.8, 1.2]);
      expect(s.averageSpeed, closeTo(1.0, 1e-9));
    });

    test('ordena calorías e intervalos de pasos (count ausente = 0)', () async {
      final s = (await fetch([_nativeSession()])).single;
      expect(s.calorieSeries.map((p) => p.kcal), [30.5, 40]);
      expect(s.stepSeries.map((p) => p.count), [0, 200]);
    });

    test('parsea vueltas con largo por defecto 0', () async {
      final s = (await fetch([_nativeSession()])).single;
      expect(s.laps.map((l) => l.lengthMeters), [25.0, 0.0]);
    });

    test('parsea segmentos con tipo y repeticiones por defecto 0', () async {
      final s = (await fetch([_nativeSession()])).single;
      expect(s.segments.first.segmentType, 4);
      expect(s.segments.first.repetitions, 3);
      expect(s.segments.last.segmentType, 0);
      expect(s.segments.last.repetitions, 0);
    });

    const typeNames = {
      57: 'SWIMMING_POOL',
      56: 'SWIMMING_OPEN_WATER',
      40: 'RUNNING',
      4: 'BIKING',
      61: 'WALKING',
      0: 'ENTRENAMIENTO',
      999: 'TIPO_999',
    };
    for (final entry in typeNames.entries) {
      test('exerciseType ${entry.key} → ${entry.value}', () async {
        final s = (await fetch([_nativeSession(exerciseType: entry.key)])).single;
        expect(s.activityType, entry.value);
      });
    }

    test('sin exerciseType usa ENTRENAMIENTO', () async {
      final s = (await fetch([_nativeSession(exerciseType: null)])).single;
      expect(s.activityType, 'ENTRENAMIENTO');
    });

    test('sin id usa el epoch del inicio', () async {
      final s = (await fetch([_nativeSession(id: null)])).single;
      expect(s.id, '${_start.millisecondsSinceEpoch}');
    });

    test('sin distancia ni calorías usa 0', () async {
      final s = (await fetch([_nativeSession(distance: null, calories: null)])).single;
      expect(s.distance, 0);
      expect(s.calories, 0);
    });

    test('sesión sin series deja promedios nulos', () async {
      final s = (await fetch([
        {'id': 'vacia', 'startMs': _ms(0), 'endMs': _ms(60)}
      ]))
          .single;
      expect(s.heartRateSeries, isEmpty);
      expect(s.averageHeartRate, isNull);
      expect(s.maxHeartRate, isNull);
      expect(s.spo2, isNull);
      expect(s.averageSpeed, isNull);
      expect(s.waterTemperature, isNull);
    });

    test('devuelve las sesiones de la más reciente a la más antigua', () async {
      final sessions = await fetch([
        _nativeSession(id: 'vieja', startSec: 0, endSec: 600),
        _nativeSession(id: 'nueva', startSec: 86400, endSec: 87000),
      ]);
      expect(sessions.map((s) => s.id), ['nueva', 'vieja']);
    });
  });

  group('fetchSwimSessions (fallback al paquete health)', () {
    test('lista nativa vacía y sin workouts devuelve vacío', () async {
      _mockChannel({'getExerciseSessions': '[]'});
      final result = await HealthService.forTesting(FakeHealthPlugin())
          .fetchSwimSessions(UserProfile.defaultProfile());
      expect(result, isEmpty);
    });

    test('canal nativo con error y paquete health con error devuelve vacío', () async {
      _mockChannel({'getExerciseSessions': PlatformException(code: 'x')});
      final result = await HealthService.forTesting(
              FakeHealthPlugin(configureError: Exception('sin HC')))
          .fetchSwimSessions(UserProfile.defaultProfile());
      expect(result, isEmpty);
    });

    test('arma sesiones desde WORKOUT con FC y SpO2 dentro de la ventana', () async {
      final now = DateTime.now().subtract(const Duration(days: 1));
      _mockChannel({'getExerciseSessions': null});
      final plugin = FakeHealthPlugin(points: [
        workoutPoint(now, 1800, distance: 1200, energy: 280),
        numericPoint(HealthDataType.HEART_RATE, now.add(const Duration(minutes: 1)), 120),
        numericPoint(HealthDataType.HEART_RATE, now.add(const Duration(minutes: 2)), 140),
        numericPoint(HealthDataType.HEART_RATE, now.add(const Duration(hours: 3)), 60),
        numericPoint(HealthDataType.BLOOD_OXYGEN, now.add(const Duration(minutes: 5)), 97),
      ]);
      final s = (await HealthService.forTesting(plugin)
              .fetchSwimSessions(UserProfile.defaultProfile()))
          .single;
      expect(s.distance, 1200);
      expect(s.calories, 280);
      expect(s.heartRateSeries.map((p) => p.bpm), [120, 140]);
      expect(s.averageHeartRate, 130);
      expect(s.maxHeartRate, 140);
      expect(s.spo2, 97);
      expect(s.activityType, 'SWIMMING');
    });

    test('sin totales en el workout suma DISTANCE_DELTA y ACTIVE_ENERGY_BURNED', () async {
      final now = DateTime.now().subtract(const Duration(days: 2));
      _mockChannel({'getExerciseSessions': '[]'});
      final plugin = FakeHealthPlugin(points: [
        workoutPoint(now, 1800),
        numericPoint(HealthDataType.DISTANCE_DELTA, now.add(const Duration(minutes: 1)), 400),
        numericPoint(HealthDataType.DISTANCE_DELTA, now.add(const Duration(minutes: 10)), 600),
        numericPoint(HealthDataType.ACTIVE_ENERGY_BURNED, now.add(const Duration(minutes: 3)), 75),
      ]);
      final s = (await HealthService.forTesting(plugin)
              .fetchSwimSessions(UserProfile.defaultProfile()))
          .single;
      expect(s.distance, 1000);
      expect(s.calories, 75);
      expect(s.spo2, isNull);
    });

    test('sin totales ni deltas usa 0', () async {
      final now = DateTime.now().subtract(const Duration(days: 2));
      _mockChannel({'getExerciseSessions': '[]'});
      final plugin = FakeHealthPlugin(points: [workoutPoint(now, 600)]);
      final s = (await HealthService.forTesting(plugin)
              .fetchSwimSessions(UserProfile.defaultProfile()))
          .single;
      expect(s.distance, 0);
      expect(s.calories, 0);
      expect(s.heartRateSeries, isEmpty);
    });

    test('un tipo que falla no impide leer los demás', () async {
      final now = DateTime.now().subtract(const Duration(days: 1));
      _mockChannel({'getExerciseSessions': '[]'});
      final plugin = FakeHealthPlugin(
        points: [workoutPoint(now, 600, distance: 500, energy: 90)],
        failingTypes: {HealthDataType.HEART_RATE},
      );
      final result = await HealthService.forTesting(plugin)
          .fetchSwimSessions(UserProfile.defaultProfile());
      expect(result.single.distance, 500);
    });

    test('varios workouts salen del más reciente al más antiguo', () async {
      final a = DateTime.now().subtract(const Duration(days: 5));
      final b = DateTime.now().subtract(const Duration(days: 1));
      _mockChannel({'getExerciseSessions': '[]'});
      final plugin = FakeHealthPlugin(points: [workoutPoint(a, 600), workoutPoint(b, 600)]);
      final result = await HealthService.forTesting(plugin)
          .fetchSwimSessions(UserProfile.defaultProfile());
      expect(result.first.startTime, b);
      expect(result.last.startTime, a);
    });
  });

  group('exportFullDumpJson', () {
    test('devuelve el texto del canal nativo', () async {
      _mockChannel({'exportFullDump': '{"sessions": [1]}'});
      expect(await HealthService.forTesting(FakeHealthPlugin()).exportFullDumpJson(),
          '{"sessions": [1]}');
    });

    test('si el canal devuelve null, devuelve un JSON de error', () async {
      _mockChannel({'exportFullDump': null});
      final text = await HealthService.forTesting(FakeHealthPlugin()).exportFullDumpJson();
      expect(jsonDecode(text)['error'], contains('no devolvió nada'));
    });

    test('pasa el rango de días pedido', () async {
      final log = <MethodCall>[];
      _mockChannel({'exportFullDump': '{}'}, log: log);
      await HealthService.forTesting(FakeHealthPlugin())
          .exportFullDumpJson(days: const Duration(days: 7));
      final args = log.single.arguments as Map;
      final span = (args['endMs'] as int) - (args['startMs'] as int);
      expect(span, const Duration(days: 7, minutes: 15).inMilliseconds);
    });
  });

  group('fetchRawHealthData', () {
    test('ordena lo que da el canal nativo del más nuevo al más viejo', () async {
      _mockChannel({
        'getRawHealthPoints': jsonEncode([
          {'type': 'HEART_RATE', 'dateFromEpochMs': 1},
          {'type': 'WORKOUT', 'dateFromEpochMs': 3},
          {'type': 'BLOOD_OXYGEN', 'dateFromEpochMs': 2},
        ])
      });
      final list = await HealthService.forTesting(FakeHealthPlugin()).fetchRawHealthData();
      expect(list.map((e) => e['dateFromEpochMs']), [3, 2, 1]);
    });

    test('canal nativo con error cae al paquete health y lo convierte a mapas', () async {
      final now = DateTime.now().subtract(const Duration(hours: 2));
      _mockChannel({'getRawHealthPoints': PlatformException(code: 'x')});
      final plugin = FakeHealthPlugin(points: [
        numericPoint(HealthDataType.HEART_RATE, now, 133, unit: HealthDataUnit.BEATS_PER_MINUTE),
        workoutPoint(now.add(const Duration(minutes: 1)), 900, distance: 750, energy: 150),
      ]);
      final list = await HealthService.forTesting(plugin).fetchRawHealthData();
      expect(list.length, 2);

      final workout = list.firstWhere((e) => e['type'] == 'WORKOUT');
      expect(workout['value']['kind'], 'WorkoutHealthValue');
      expect(workout['value']['workoutActivityType'], 'SWIMMING');
      expect(workout['value']['totalDistance'], 750);
      expect(workout['value']['totalDistanceUnit'], 'METER');
      expect(workout['value']['totalEnergyBurned'], 150);
      expect(workout['value']['totalEnergyBurnedUnit'], 'KILOCALORIE');
      expect(workout['durationSeconds'], 900);

      final hr = list.firstWhere((e) => e['type'] == 'HEART_RATE');
      expect(hr['value'], {'kind': 'NumericHealthValue', 'numericValue': 133});
      expect(hr['unit'], 'BEATS_PER_MINUTE');
      expect(hr['sourceName'], 'Mi Fitness');
      expect(hr['sourcePlatform'], 'googleHealthConnect');
      expect(hr['dateFromEpochMs'], now.millisecondsSinceEpoch);
    });

    test('el fallback también ordena del más nuevo al más viejo', () async {
      final now = DateTime.now().subtract(const Duration(hours: 5));
      _mockChannel({'getRawHealthPoints': null});
      final plugin = FakeHealthPlugin(points: [
        numericPoint(HealthDataType.HEART_RATE, now, 100),
        numericPoint(HealthDataType.HEART_RATE, now.add(const Duration(hours: 1)), 110),
      ]);
      final list = await HealthService.forTesting(plugin).fetchRawHealthData();
      expect(list.map((e) => e['value']['numericValue']), [110, 100]);
    });

    test('si todo falla devuelve lista vacía', () async {
      _mockChannel({'getRawHealthPoints': PlatformException(code: 'x')});
      final list = await HealthService.forTesting(
              FakeHealthPlugin(configureError: Exception('sin HC')))
          .fetchRawHealthData();
      expect(list, isEmpty);
    });
  });

  group('installHealthConnect', () {
    test('propaga el error del paquete health', () async {
      final service = HealthService.forTesting(_ThrowingInstallPlugin());
      await expectLater(service.installHealthConnect(), throwsException);
    });

    test('no lanza si la instalación funciona', () async {
      final service = HealthService.forTesting(_OkInstallPlugin());
      await service.installHealthConnect();
    });
  });

  test('HealthService() es un singleton', () {
    expect(identical(HealthService(), HealthService()), isTrue);
  });
}

class _ThrowingInstallPlugin extends FakeHealthPlugin {
  @override
  Future<void> installHealthConnect() async => throw Exception('sin Play Store');
}

class _OkInstallPlugin extends FakeHealthPlugin {
  @override
  Future<void> installHealthConnect() async {}
}
