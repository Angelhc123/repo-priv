import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/screens/raw_json_screen.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

const _tall = Size(1400, 6000);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  final points = [
    rawPoint('WORKOUT', kStart, seconds: 1800, value: {'kind': 'WorkoutHealthValue'}),
    rawPoint('HEART_RATE', kStart, numericValue: 140),
    rawPoint('HEART_RATE', kStart.add(const Duration(minutes: 1)), numericValue: 150),
    rawPoint('DISTANCE_DELTA', kStart, numericValue: 25),
    rawPoint('SPEED', kStart, numericValue: 1.1),
    rawPoint('BLOOD_OXYGEN', kStart, numericValue: 97, sourceName: 'Oxímetro'),
    rawPoint('ACTIVE_ENERGY_BURNED', kStart, numericValue: 12),
    rawPoint('SLEEP', kStart),
  ];

  Future<StubHealthService> pumpRaw(WidgetTester tester,
      {List<Map<String, dynamic>>? raw}) async {
    final health = StubHealthService(rawPoints: raw ?? points);
    final state = await buildAppState(health: health, signedIn: false);
    await pumpScreen(tester, RawJsonScreen(appState: state), size: _tall);
    await tester.pumpAndSettle();
    return health;
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);

  testWidgets('muestra el título y el banner explicativo', (tester) async {
    await pumpRaw(tester);
    expect(find.text('Inspector JSON Crudo'), findsOneWidget);
    expect(find.text('Datos Sin Procesar de Health Connect'), findsOneWidget);
  });

  testWidgets('muestra el indicador mientras carga', (tester) async {
    final state = await buildAppState(signedIn: false);
    await pumpScreen(tester, RawJsonScreen(appState: state), size: _tall);
    expect(find.text('Consultando registros crudos en Health Connect...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Consultando registros crudos en Health Connect...'), findsNothing);
  });

  testWidgets('consulta 30 días por defecto', (tester) async {
    final health = await pumpRaw(tester);
    expect(health.lastRawDays, const Duration(days: 30));
  });

  testWidgets('muestra el total y los resultados', (tester) async {
    await pumpRaw(tester);
    expect(find.text('Resultados: 8 objetos crudos'), findsOneWidget);
    expect(find.text('Total en DB: 8'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNWidgets(8));
  });

  testWidgets('tiene un chip por filtro', (tester) async {
    await pumpRaw(tester);
    expect(find.byType(ChoiceChip), findsNWidgets(7));
  });

  for (final (label, expected) in const [
    ('WORKOUT', 1),
    ('HEART_RATE', 2),
    ('DISTANCE', 1),
    ('SPEED', 1),
    ('SPO2', 1),
    ('CALORIES', 1),
  ]) {
    testWidgets('filtro $label deja $expected resultado(s)', (tester) async {
      await pumpRaw(tester);
      await tester.tap(chip(label));
      await tester.pumpAndSettle();
      expect(find.text('Resultados: $expected objetos crudos'), findsOneWidget);
    });
  }

  testWidgets('volver a TODOS muestra todo', (tester) async {
    await pumpRaw(tester);
    await tester.tap(chip('SPEED'));
    await tester.pumpAndSettle();
    await tester.tap(chip('TODOS'));
    await tester.pumpAndSettle();
    expect(find.text('Resultados: 8 objetos crudos'), findsOneWidget);
  });

  testWidgets('la búsqueda filtra por contenido del JSON', (tester) async {
    await pumpRaw(tester);
    await tester.enterText(find.byType(TextField), 'oxímetro');
    await tester.pumpAndSettle();
    expect(find.text('Resultados: 1 objetos crudos'), findsOneWidget);
  });

  testWidgets('la búsqueda no distingue mayúsculas', (tester) async {
    await pumpRaw(tester);
    await tester.enterText(find.byType(TextField), 'heart_rate');
    await tester.pumpAndSettle();
    expect(find.text('Resultados: 2 objetos crudos'), findsOneWidget);
  });

  testWidgets('el botón de limpiar borra la búsqueda', (tester) async {
    await pumpRaw(tester);
    await tester.enterText(find.byType(TextField), 'nada-coincide');
    await tester.pumpAndSettle();
    expect(find.text('Resultados: 0 objetos crudos'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Resultados: 8 objetos crudos'), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsNothing);
  });

  testWidgets('sin resultados con filtro sugiere cambiar el filtro', (tester) async {
    await pumpRaw(tester, raw: [rawPoint('HEART_RATE', kStart)]);
    await tester.tap(chip('WORKOUT'));
    await tester.pumpAndSettle();
    expect(find.text('No se encontraron objetos crudos en Health Connect'), findsOneWidget);
    expect(find.textContaining("cambiar el filtro 'WORKOUT'"), findsOneWidget);
  });

  testWidgets('sin datos y sin filtro sugiere revisar permisos', (tester) async {
    await pumpRaw(tester, raw: []);
    expect(find.textContaining('Verifica si Mi Fitness tiene permiso'), findsOneWidget);
  });

  testWidgets('sin datos el ícono de copiar todo queda deshabilitado', (tester) async {
    await pumpRaw(tester, raw: []);
    final button = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.copy_all));
    expect(button.onPressed, isNull);
  });

  testWidgets('copiar todo desde la barra', (tester) async {
    await pumpRaw(tester);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.copy_all));
    await tester.pump();
    expect(find.text('¡Todos los objetos JSON copiados al portapapeles!'), findsOneWidget);
  });

  testWidgets('copiar JSON completo desde el banner', (tester) async {
    await pumpRaw(tester);
    await tester.tap(find.text('Copiar JSON Completo'));
    await tester.pump();
    expect(find.text('¡JSON completo copiado!'), findsOneWidget);
  });

  testWidgets('el primer registro y los WORKOUT arrancan expandidos', (tester) async {
    await pumpRaw(tester);
    // primero = WORKOUT (índice 0) → expandido; solo uno tiene el botón visible.
    expect(find.byTooltip('Copiar este JSON'), findsOneWidget);
  });

  testWidgets('copiar un registro expandido', (tester) async {
    await pumpRaw(tester);
    await tester.tap(find.byTooltip('Copiar este JSON'));
    await tester.pump();
    expect(find.text('¡JSON de WORKOUT copiado!'), findsOneWidget);
  });

  testWidgets('expandir otro registro muestra su JSON', (tester) async {
    await pumpRaw(tester);
    await tester.tap(find.text('BLOOD_OXYGEN'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Copiar este JSON'), findsNWidgets(2));
  });

  testWidgets('cada tarjeta muestra duración y fechas', (tester) async {
    await pumpRaw(tester, raw: [rawPoint('HEART_RATE', kStart, seconds: 42)]);
    expect(find.text('Duración: 42s'), findsOneWidget);
    expect(find.textContaining('Desde: ${kStart.toIso8601String()}'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
  });

  testWidgets('registro sin tipo se muestra como DESCONOCIDO', (tester) async {
    await pumpRaw(tester, raw: [rawPoint('X', kStart)..remove('type')]);
    expect(find.text('DESCONOCIDO'), findsOneWidget);
  });

  testWidgets('refrescar vuelve a consultar', (tester) async {
    final health = await pumpRaw(tester);
    final before = health.rawCalls;
    await tester.tap(find.byTooltip('Refrescar datos crudos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refrescar'));
    await tester.pumpAndSettle();
    expect(health.rawCalls, before + 2);
  });

  for (final (label, days) in const [('Últimas 24h', 1), ('Últimos 7 días', 7)]) {
    testWidgets('elegir "$label" consulta $days días', (tester) async {
      final health = await pumpRaw(tester);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(health.lastRawDays, Duration(days: days));
    });
  }
}
