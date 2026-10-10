import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/screens/dashboard_screen.dart';
import 'package:coswim/services/app_state.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

const _huge = Size(1400, 12000);

void main() {
  setUpAll(initSpanishDates);

  late List<String> clipboard;

  setUp(() {
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<(AppState, StubHealthService)> pumpDashboard(
    WidgetTester tester, {
    List<SwimSession> sessions = const [],
    List<Map<String, dynamic>> raw = const [],
    StubHealthService? health,
  }) async {
    final h = health ?? StubHealthService(sessions: sessions, rawPoints: raw);
    final state = await buildAppState(health: h, signedIn: false);
    await pumpScreen(tester, DashboardScreen(appState: state), size: _huge);
    await tester.pumpAndSettle();
    return (state, h);
  }

  /// Puntos crudos dentro de la ventana de [buildSession] (kStart, 20 min).
  List<Map<String, dynamic>> rawInsideSession() => [
        rawPoint('DISTANCE_DELTA', kStart.add(const Duration(minutes: 1)), numericValue: 250),
        rawPoint('DISTANCE_DELTA', kStart.add(const Duration(minutes: 5)), numericValue: 500),
        rawPoint('BLOOD_OXYGEN', kStart.add(const Duration(minutes: 2)), numericValue: 97, unit: 'PERCENT'),
        rawPoint('ACTIVE_ENERGY_BURNED', kStart.add(const Duration(minutes: 3)),
            numericValue: 55, unit: 'KILOCALORIE'),
        rawPoint('HEART_RATE', kStart.add(const Duration(minutes: 4)), numericValue: 140),
        rawPoint('HEART_RATE', kStart.add(const Duration(days: 3)), numericValue: 70),
      ];

  group('carga inicial', () {
    testWidgets('muestra el título', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Datos de Health Connect'), findsOneWidget);
    });

    testWidgets('muestra el indicador mientras consulta', (tester) async {
      final state = await buildAppState(signedIn: false);
      await pumpScreen(tester, DashboardScreen(appState: state), size: _huge);
      expect(find.text('Consultando Health Connect...'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('Consultando Health Connect...'), findsNothing);
    });

    testWidgets('pide permisos y refresca después del primer frame', (tester) async {
      final (_, health) = await pumpDashboard(tester);
      expect(health.permissionCalls, 1);
      expect(health.fetchCalls, greaterThanOrEqualTo(2)); // init + refresh
      expect(health.rawCalls, greaterThanOrEqualTo(2)); // _loadAll + refresh
    });

    testWidgets('consulta los últimos 30 días por defecto', (tester) async {
      final (_, health) = await pumpDashboard(tester);
      expect(health.lastRawDays, const Duration(days: 30));
    });
  });

  group('resumen', () {
    testWidgets('cuenta entrenamientos y registros', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession()], raw: rawInsideSession());
      expect(find.text('ENTRENAMIENTOS'), findsOneWidget);
      expect(find.text('TOTAL REGISTROS'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('ENTRENAMIENTOS DETECTADOS (1)'), findsOneWidget);
    });

    testWidgets('agrupa los registros por tipo', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession()], raw: rawInsideSession());
      expect(find.text('HEART_RATE: 2'), findsOneWidget);
      expect(find.text('DISTANCE_DELTA: 2'), findsOneWidget);
      expect(find.text('BLOOD_OXYGEN: 1'), findsOneWidget);
      expect(find.text('ACTIVE_ENERGY_BURNED: 1'), findsOneWidget);
    });

    testWidgets('registros sin tipo se agrupan como DESCONOCIDO', (tester) async {
      final p = rawPoint('X', kStart)..remove('type');
      await pumpDashboard(tester, raw: [p]);
      expect(find.text('DESCONOCIDO: 1'), findsOneWidget);
    });

    testWidgets('sin registros no muestra el botón de copiar todo', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('Copiar todo el JSON crudo'), findsNothing);
      final copyAll = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.copy_all));
      expect(copyAll.onPressed, isNull);
    });

    testWidgets('copiar todo el JSON lo manda al portapapeles', (tester) async {
      await pumpDashboard(tester, raw: rawInsideSession());
      await tester.tap(find.text('Copiar todo el JSON crudo'));
      await tester.pump();
      expect(clipboard.single, contains('"type": "DISTANCE_DELTA"'));
      expect(find.text('¡JSON completo copiado!'), findsOneWidget);
    });

    testWidgets('el ícono de copiar todo informa cuántos objetos copió', (tester) async {
      await pumpDashboard(tester, raw: rawInsideSession());
      await tester.tap(find.widgetWithIcon(IconButton, Icons.copy_all).first);
      await tester.pump();
      expect(find.text('¡Todo el JSON copiado (6 objetos)!'), findsOneWidget);
    });
  });

  group('errores y estado vacío', () {
    testWidgets('muestra el banner de error de AppState', (tester) async {
      await pumpDashboard(tester, health: StubHealthService(fetchError: Exception('HC caído')));
      expect(find.textContaining('HC caído'), findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });

    testWidgets('sin entrenamientos muestra la guía de permisos', (tester) async {
      await pumpDashboard(tester);
      expect(find.text('No se encontraron registros WORKOUT'), findsOneWidget);
      expect(find.text('Solicitar permisos ahora'), findsOneWidget);
    });

    testWidgets('sin registros muestra el aviso de Health Connect vacío', (tester) async {
      await pumpDashboard(tester);
      expect(find.textContaining('Health Connect no devolvió ningún dato'), findsOneWidget);
    });

    testWidgets('"Solicitar permisos ahora" pide permisos y refresca si se conceden', (tester) async {
      final (_, health) = await pumpDashboard(tester);
      final before = health.fetchCalls;
      await tester.tap(find.text('Solicitar permisos ahora'));
      await tester.pumpAndSettle();
      expect(health.permissionCalls, 2);
      expect(health.fetchCalls, before + 1);
    });

    testWidgets('si se niegan los permisos no refresca', (tester) async {
      final (_, health) =
          await pumpDashboard(tester, health: StubHealthService(permissionResult: false));
      final before = health.fetchCalls;
      await tester.tap(find.text('Solicitar permisos ahora'));
      await tester.pumpAndSettle();
      expect(health.fetchCalls, before);
    });

    testWidgets('"Ya lo hice, refrescar" vuelve a leer', (tester) async {
      final (_, health) = await pumpDashboard(tester);
      final before = health.fetchCalls;
      await tester.tap(find.text('Ya lo hice, refrescar'));
      await tester.pumpAndSettle();
      expect(health.fetchCalls, before + 1);
    });
  });

  group('tarjeta de entrenamiento', () {
    testWidgets('encabezado con número y tipo de actividad', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession()]);
      expect(find.text('#1  SWIMMING_POOL'), findsOneWidget);
    });

    testWidgets('sin tipo de actividad dice ENTRENAMIENTO', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(activityType: null)]);
      expect(find.text('#1  ENTRENAMIENTO'), findsOneWidget);
    });

    testWidgets('muestra tiempos y duración', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(durationSeconds: 1250)]);
      expect(find.text(kStart.toIso8601String()), findsOneWidget);
      expect(find.text('1250 seg  (20 min 50 seg)'), findsOneWidget);
    });

    testWidgets('muestra las métricas con decimales', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(distance: 1000, calories: 250)]);
      expect(find.text('1000.00 m'), findsOneWidget);
      expect(find.text('250.00 kcal'), findsOneWidget);
      expect(find.text('97.0%'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d+\.\d BPM$')), findsNWidgets(2));
    });

    testWidgets('sin FC ni SpO2 muestra N/A', (tester) async {
      await pumpDashboard(tester, sessions: [bareSession()]);
      expect(find.text('N/A'), findsNWidgets(3));
    });

    testWidgets('lista los tramos DISTANCE_DELTA dentro de la sesión', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession()], raw: rawInsideSession());
      expect(find.text('TRAMOS / VUELTAS — DISTANCE_DELTA (2)'), findsOneWidget);
      expect(find.textContaining('Tramo 1: 250 METER'), findsOneWidget);
    });

    testWidgets('sin DISTANCE_DELTA explica por qué no hay tramos', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession()]);
      expect(find.textContaining('TRAMOS / VUELTAS: 0 registros'), findsOneWidget);
    });

    testWidgets('lista SpO2 y calorías de la ventana de la sesión', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession()], raw: rawInsideSession());
      expect(find.text('SpO2 DURANTE ENTRENAMIENTO (1)'), findsOneWidget);
      expect(find.text('CALORÍAS POR TRAMO (1)'), findsOneWidget);
      expect(find.textContaining('→  97 %'), findsOneWidget);
      expect(find.textContaining('55 kcal'), findsOneWidget);
    });

    testWidgets('registros sin valor se marcan como "(sin valor)"', (tester) async {
      final raw = [
        rawPoint('DISTANCE_DELTA', kStart.add(const Duration(minutes: 1)), value: {}),
        rawPoint('BLOOD_OXYGEN', kStart.add(const Duration(minutes: 2)), value: {}),
      ];
      await pumpDashboard(tester, sessions: [buildSession()], raw: raw);
      expect(find.textContaining('(sin valor)'), findsNWidgets(2));
    });

    testWidgets('registros con fecha inválida se ignoran en la sesión', (tester) async {
      final bad = rawPoint('DISTANCE_DELTA', kStart)..['dateFrom'] = 'no-fecha';
      await pumpDashboard(tester, sessions: [buildSession()], raw: [bad]);
      expect(find.textContaining('TRAMOS / VUELTAS: 0 registros'), findsOneWidget);
    });

    testWidgets('muestra velocidad y FC de la sesión', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(durationSeconds: 100)]);
      expect(find.text('VELOCIDAD — SpeedRecord (11)'), findsOneWidget);
      expect(find.text('FC (11)'), findsOneWidget);
    });

    testWidgets('incluye el JSON completo de la sesión', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(id: 'json-id')]);
      expect(find.text('JSON COMPLETO DEL OBJETO SESIÓN:'), findsOneWidget);
      expect(find.textContaining('"id": "json-id"'), findsOneWidget);
    });

    testWidgets('copiar el JSON de la sesión', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(id: 'copiame')]);
      await tester.tap(find.byTooltip('Copiar JSON completo'));
      await tester.pump();
      expect(clipboard.single, contains('"id": "copiame"'));
      expect(find.text('¡JSON de sesión #1 copiado!'), findsOneWidget);
    });

    testWidgets('numera varias sesiones', (tester) async {
      await pumpDashboard(tester, sessions: buildHistory(3));
      expect(find.textContaining(RegExp(r'^#[123]  ')), findsNWidgets(3));
      expect(find.text('ENTRENAMIENTOS DETECTADOS (3)'), findsOneWidget);
    });
  });

  group('listas largas', () {
    testWidgets('más de 100 líneas se colapsan con "Ver todos"', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(durationSeconds: 1200)]);
      // 121 muestras de FC y de velocidad.
      expect(find.text('▼ Ver todos (121)'), findsNWidgets(2));
      expect(find.text('▼ Ver 21 más'), findsNWidgets(2));
    });

    testWidgets('"Ver todos" expande y "Colapsar" vuelve atrás', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(durationSeconds: 1200)]);
      await scrollAndTap(tester, find.text('▼ Ver todos (121)').first);
      await tester.pumpAndSettle();
      expect(find.text('▲ Colapsar'), findsOneWidget);
      expect(find.text('▼ Ver 21 más'), findsOneWidget);

      await scrollAndTap(tester, find.text('▲ Colapsar'));
      await tester.pumpAndSettle();
      expect(find.text('▲ Colapsar'), findsNothing);
      expect(find.text('▼ Ver 21 más'), findsNWidgets(2));
    });

    testWidgets('"Ver N más" también expande', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(durationSeconds: 1200)]);
      await scrollAndTap(tester, find.text('▼ Ver 21 más').first);
      await tester.pumpAndSettle();
      expect(find.text('▼ Ver 21 más'), findsOneWidget);
    });

    testWidgets('100 líneas o menos no muestran botones', (tester) async {
      await pumpDashboard(tester, sessions: [buildSession(durationSeconds: 300)]);
      expect(find.textContaining('Ver todos'), findsNothing);
    });
  });

  group('registros sueltos', () {
    testWidgets('están ocultos hasta pedirlos', (tester) async {
      await pumpDashboard(tester, raw: rawInsideSession());
      expect(find.text('Mostrar los 6 registros sueltos'), findsOneWidget);
      expect(find.text('JSON COMPLETO:'), findsNothing);
    });

    testWidgets('al abrirlos muestra una sección por tipo y se pueden ocultar', (tester) async {
      await pumpDashboard(tester, raw: rawInsideSession());
      await scrollAndTap(tester, find.text('Mostrar los 6 registros sueltos'));
      await tester.pumpAndSettle();
      expect(find.text('HEART_RATE  (2 registros)'), findsOneWidget);
      expect(find.text('DISTANCE_DELTA  (2 registros)'), findsOneWidget);
      expect(find.text('JSON COMPLETO:'), findsNWidgets(6));

      await scrollAndTap(tester, find.text('Ocultar registros sueltos'));
      await tester.pumpAndSettle();
      expect(find.text('JSON COMPLETO:'), findsNothing);
    });

    testWidgets('formatea valores numéricos, de workout y desconocidos', (tester) async {
      final raw = [
        rawPoint('HEART_RATE', kStart, numericValue: 133, unit: 'BEATS_PER_MINUTE'),
        rawPoint('WORKOUT', kStart, value: {
          'kind': 'WorkoutHealthValue',
          'workoutActivityType': 'SWIMMING',
          'totalDistance': 1200,
          'totalDistanceUnit': 'METER',
          'totalEnergyBurned': 300,
        }),
        rawPoint('WORKOUT', kStart.add(const Duration(days: 1)),
            value: {'kind': 'WorkoutHealthValue', 'workoutActivityType': 'OTHER'}),
        rawPoint('SLEEP', kStart, value: {'kind': 'Otro', 'rawString': 'texto crudo'}),
        rawPoint('STEPS', kStart, value: {'kind': 'Raro'}),
      ];
      await pumpDashboard(tester, raw: raw);
      await scrollAndTap(tester, find.text('Mostrar los 5 registros sueltos'));
      await tester.pumpAndSettle();
      expect(find.text('133 BEATS_PER_MINUTE'), findsOneWidget);
      expect(find.text('Actividad: SWIMMING | Distancia: 1200 METER | Energía: 300 kcal'),
          findsOneWidget);
      expect(find.text('Actividad: OTHER'), findsOneWidget);
      expect(find.text('texto crudo'), findsOneWidget);
      expect(find.text('{kind: Raro}'), findsOneWidget);
    });

    testWidgets('campos vacíos se muestran como "(vacío)" / "(sin unidad)"', (tester) async {
      await pumpDashboard(tester, raw: [rawPoint('HEART_RATE', kStart, sourceName: '', sourceId: '', unit: '')]);
      await scrollAndTap(tester, find.text('Mostrar los 1 registros sueltos'));
      await tester.pumpAndSettle();
      expect(find.text('(vacío)'), findsNWidgets(2));
      expect(find.text('(sin unidad)'), findsOneWidget);
    });

    testWidgets('copiar todos los registros de un tipo', (tester) async {
      await pumpDashboard(tester, raw: rawInsideSession());
      await scrollAndTap(tester, find.text('Mostrar los 6 registros sueltos'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.byTooltip('Copiar todos los registros de HEART_RATE'));
      await tester.pump();
      expect(find.text('¡2 registros de HEART_RATE copiados!'), findsOneWidget);
    });

    testWidgets('copiar un registro individual', (tester) async {
      await pumpDashboard(tester, raw: [rawPoint('BLOOD_OXYGEN', kStart, numericValue: 96)]);
      await scrollAndTap(tester, find.text('Mostrar los 1 registros sueltos'));
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.byTooltip('Copiar este registro'));
      await tester.pump();
      expect(find.text('¡JSON de BLOOD_OXYGEN #1 copiado!'), findsOneWidget);
      expect(clipboard.single, contains('"numericValue": 96'));
    });
  });

  group('acciones de la barra', () {
    testWidgets('el botón refrescar vuelve a consultar', (tester) async {
      final (_, health) = await pumpDashboard(tester);
      final before = health.rawCalls;
      await tester.tap(find.byTooltip('Refrescar datos de Health Connect'));
      await tester.pumpAndSettle();
      expect(health.rawCalls, before + 1);
    });

    for (final (label, days) in const [('24h', 1), ('7 días', 7), ('1 año', 365)]) {
      testWidgets('elegir "$label" consulta $days días', (tester) async {
        final (_, health) = await pumpDashboard(tester);
        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(health.lastRawDays, Duration(days: days));
      });
    }

    testWidgets('si exportar falla avisa con un SnackBar', (tester) async {
      await pumpDashboard(tester);
      await tester.tap(find.byIcon(Icons.download_for_offline));
      await tester.pumpAndSettle();
      expect(find.textContaining('No se pudo exportar'), findsOneWidget);
      expect(find.byIcon(Icons.download_for_offline), findsOneWidget);
    });
  });
}
