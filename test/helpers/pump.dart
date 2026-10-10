import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Pantalla grande por defecto para que los layouts pensados para teléfono
/// (filas con varias tarjetas) no desborden en el entorno de test.
const kTestSurface = Size(1400, 2400);

Future<void> initSpanishDates() => initializeDateFormatting('es', null);

/// Monta [child] dentro de un MaterialApp con el tema oscuro de la app.
Future<void> pumpScreen(WidgetTester tester, Widget child, {Size size = kTestSurface}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: child,
  ));
}

/// Hace scroll hasta que [finder] sea visible y lo toca.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}
