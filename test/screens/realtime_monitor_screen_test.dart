import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/screens/realtime_monitor_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/pump.dart';

const _tall = Size(1400, 4000);

/// El corazón animado repite su animación para siempre, así que acá nunca se
/// usa pumpAndSettle: se avanza el reloj a mano.
Future<FakeHealthPlugin> _pumpMonitor(
  WidgetTester tester, {
  List<HealthDataPoint> points = const [],
  Object? configureError,
  Set<HealthDataType> failingTypes = const {},
  UserProfile? profile,
}) async {
  final plugin = FakeHealthPlugin(
      points: points, configureError: configureError, failingTypes: failingTypes);
  final state = await buildAppState(signedIn: false, profile: profile);
  await pumpScreen(tester, RealtimeMonitorScreen(appState: state, health: plugin), size: _tall);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return plugin;
}

DateTime _ago(Duration d) => DateTime.now().subtract(d);

void main() {
  group('sin datos', () {
    testWidgets('arranca monitoreando', (tester) async {
      await _pumpMonitor(tester);
      expect(find.text('Monitor Live'), findsOneWidget);
      expect(find.text('ESTADO: ACTIVO'), findsOneWidget);
      expect(find.text('Detener'), findsOneWidget);
    });

    testWidgets('consulta Health Connect al iniciar', (tester) async {
      final plugin = await _pumpMonitor(tester);
      expect(plugin.configureCalls, 1);
    });

    testWidgets('FC sin lecturas', (tester) async {
      await _pumpMonitor(tester);
      expect(find.text('Sin Datos'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
      expect(find.text('Sin lecturas recientes'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testWidgets('SpO2, calorías y distancia en cero', (tester) async {
      await _pumpMonitor(tester);
      expect(find.text('N/A'), findsNWidgets(2)); // SpO2 y temperatura
      expect(find.text('0.0 kcal'), findsOneWidget);
      expect(find.text('0.0 metros'), findsOneWidget);
      expect(find.text('--:--'), findsOneWidget);
    });

    testWidgets('temperatura del agua no disponible', (tester) async {
      await _pumpMonitor(tester);
      expect(find.textContaining('limitación del Redmi Watch 4'), findsOneWidget);
    });

    testWidgets('muestra el aviso de que Health Connect no es un stream', (tester) async {
      await _pumpMonitor(tester);
      expect(find.textContaining('Health Connect NO es un stream en vivo'), findsOneWidget);
    });
  });

  group('con lecturas', () {
    testWidgets('muestra la FC más reciente y su zona', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(hours: 2)), 90),
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(seconds: 70)), 150),
      ]);
      // edad 22 → FC máx 198; 150/198 = 75.7% → zona 3.
      expect(find.text('150'), findsOneWidget);
      expect(find.text('Zona 3'), findsOneWidget);
      expect(find.text('Aeróbico moderado'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });

    testWidgets('lectura de hace segundos dice "En Vivo"', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(seconds: 70)), 120),
      ]);
      expect(find.text('Sincronizado: En Vivo'), findsOneWidget);
    });

    testWidgets('lectura de hace media hora dice los minutos', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(minutes: 31)), 120),
      ]);
      expect(find.text('Sincronizado hace 30 min'), findsOneWidget);
    });

    testWidgets('lectura de hace horas dice las horas', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(hours: 3, minutes: 1)), 120),
      ]);
      expect(find.text('Sincronizado hace 3 horas'), findsOneWidget);
    });

    testWidgets('SpO2 levemente baja muestra el aviso', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.BLOOD_OXYGEN, _ago(const Duration(minutes: 5)), 92),
      ]);
      expect(find.text('92.0'), findsOneWidget);
      expect(find.text('Aviso: SpO2 Levemente Bajo'), findsOneWidget);
      expect(find.text('Sincronizado hace 4 min'), findsOneWidget);
    });

    testWidgets('SpO2 reciente dice "En Vivo"', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.BLOOD_OXYGEN, _ago(const Duration(seconds: 61)), 98),
      ]);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Sincronizado: En Vivo'), findsOneWidget);
    });

    testWidgets('SpO2 de hace horas dice las horas', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.BLOOD_OXYGEN, _ago(const Duration(hours: 5, minutes: 1)), 97),
      ]);
      expect(find.text('Sincronizado hace 5 horas'), findsOneWidget);
    });

    testWidgets('suma calorías y distancia del período', (tester) async {
      final t = _ago(const Duration(hours: 1));
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.ACTIVE_ENERGY_BURNED, t, 100),
        numericPoint(HealthDataType.ACTIVE_ENERGY_BURNED, t, 50.5),
        numericPoint(HealthDataType.DISTANCE_DELTA, t, 500),
        numericPoint(HealthDataType.DISTANCE_DELTA, t, 250),
      ]);
      expect(find.text('150.5 kcal'), findsOneWidget);
      expect(find.text('750.0 metros'), findsOneWidget);
    });

    testWidgets('un tipo que falla no impide leer los demás', (tester) async {
      await _pumpMonitor(
        tester,
        points: [
          numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(minutes: 2)), 130),
          numericPoint(HealthDataType.DISTANCE_DELTA, _ago(const Duration(minutes: 2)), 100),
        ],
        failingTypes: {
          HealthDataType.BLOOD_OXYGEN,
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.HEART_RATE,
        },
      );
      expect(find.text('100.0 metros'), findsOneWidget);
      expect(find.text('Sin Datos'), findsOneWidget);
    });

    testWidgets('FC sobre el 90% muestra la barra hacia la alarma', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(seconds: 70)), 185),
      ]);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Superando 90% de FC Máx: 1 / 60s acumulando para alarma.'), findsOneWidget);
    });

    testWidgets('60 lecturas sobre el 90% disparan la alerta', (tester) async {
      await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(seconds: 70)), 185),
      ]);
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(seconds: 30));
      }
      await tester.pump();
      expect(find.textContaining('¡ALERTA DE ESFUERZO MÁXIMO SOSTENIDO!'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('vuelve a consultar cada 30 segundos', (tester) async {
      final plugin = await _pumpMonitor(tester);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(plugin.configureCalls, 2);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(plugin.configureCalls, 3);
    });
  });

  group('errores de conexión', () {
    testWidgets('Health Connect no disponible muestra instrucciones de instalación', (tester) async {
      await _pumpMonitor(tester,
          configureError: Exception('Health Connect is not available'));
      expect(find.textContaining('Health Connect no está instalado'), findsOneWidget);
      expect(find.text('Sin Datos'), findsOneWidget);
    });

    for (final msg in ['Unsupported operation', 'SdkStatus 2', 'service not available']) {
      testWidgets('"$msg" se trata como Health Connect no disponible', (tester) async {
        await _pumpMonitor(tester, configureError: Exception(msg));
        expect(find.textContaining('Health Connect no está instalado'), findsOneWidget);
      });
    }

    testWidgets('otro error se muestra como error de conexión', (tester) async {
      await _pumpMonitor(tester, configureError: Exception('timeout'));
      expect(find.textContaining('Error de conexión: Exception: timeout'), findsOneWidget);
    });
  });

  group('control de monitoreo', () {
    testWidgets('Detener para el monitoreo', (tester) async {
      final plugin = await _pumpMonitor(tester);
      await tester.tap(find.text('Detener'));
      await tester.pump();
      expect(find.text('ESTADO: DETENIDO'), findsOneWidget);
      expect(find.text('Esperando Inicio...'), findsOneWidget);
      expect(find.text('Iniciar'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      expect(plugin.configureCalls, 1);
    });

    testWidgets('detenido no muestra el error de conexión', (tester) async {
      await _pumpMonitor(tester, configureError: Exception('timeout'));
      await tester.tap(find.text('Detener'));
      await tester.pump();
      expect(find.textContaining('Advertencia de Conexión'), findsNothing);
    });

    testWidgets('Iniciar vuelve a monitorear y consulta de inmediato', (tester) async {
      final plugin = await _pumpMonitor(tester);
      await tester.tap(find.text('Detener'));
      await tester.pump();
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('ESTADO: ACTIVO'), findsOneWidget);
      expect(plugin.configureCalls, 2);
    });

    testWidgets('el corazón deja de latir cuando se pierden los datos', (tester) async {
      final plugin = await _pumpMonitor(tester, points: [
        numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(minutes: 2)), 120),
      ]);
      expect(find.byType(ScaleTransition), findsWidgets);
      plugin.points = [];
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      plugin.points = [numericPoint(HealthDataType.HEART_RATE, _ago(const Duration(minutes: 2)), 125)];
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(find.text('125'), findsOneWidget);
    });
  });

  group('referencia de velocidad por nivel', () {
    for (final (level, speed) in const [
      ('beginner', '40.0'),
      ('intermediate', '48.0'),
      ('advanced', '68.0'),
      ('competitive', '85.0'),
      ('otro', '40.0'),
    ]) {
      testWidgets('nivel $level → $speed m/min', (tester) async {
        await _pumpMonitor(tester, profile: UserProfile(age: 30, level: level, useMockData: false));
        expect(find.text('Referencia para tu nivel: $speed m/min.'), findsOneWidget);
      });
    }
  });

  testWidgets('la FC máxima teórica usa la edad del perfil', (tester) async {
    await _pumpMonitor(tester, profile: UserProfile(age: 40, level: 'beginner', useMockData: false));
    expect(find.text('Máximo teórico: 180 BPM (90% = 162 BPM)'), findsOneWidget);
  });
}
