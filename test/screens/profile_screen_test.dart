import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/screens/profile_screen.dart';
import 'package:coswim/services/app_state.dart';
import 'package:coswim/services/storage_service.dart';

import '../helpers/fakes.dart';
import '../helpers/pump.dart';

void main() {
  Future<AppState> pumpProfile(WidgetTester tester, {UserProfile? profile}) async {
    final state = await buildAppState(
      signedIn: false,
      profile: profile ?? UserProfile(age: 30, level: 'intermediate', useMockData: false),
    );
    await pumpScreen(tester, ProfileScreen(appState: state));
    await tester.pumpAndSettle();
    return state;
  }

  Finder ageField() => find.byType(TextFormField);
  Finder saveButton() => find.text('Guardar Cambios');

  testWidgets('muestra el título y las tres secciones', (tester) async {
    await pumpProfile(tester);
    expect(find.text('Configuración de Perfil'), findsOneWidget);
    expect(find.text('Edad del Usuario'), findsOneWidget);
    expect(find.text('Nivel de Natación Autodeclarado'), findsOneWidget);
    expect(find.text('Origen de los Datos'), findsOneWidget);
  });

  testWidgets('precarga la edad y el nivel del perfil', (tester) async {
    await pumpProfile(tester);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('Intermedio (1:45 - 2:30 min/100m)'), findsOneWidget);
  });

  testWidgets('edad vacía muestra error de validación', (tester) async {
    await pumpProfile(tester);
    await tester.enterText(ageField(), '');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu edad'), findsOneWidget);
  });

  for (final value in ['abc', '0', '-5', '121']) {
    testWidgets('edad "$value" es inválida', (tester) async {
      await pumpProfile(tester);
      await tester.enterText(ageField(), value);
      await tester.tap(saveButton());
      await tester.pumpAndSettle();
      expect(find.text('Ingresa una edad válida (1 - 120)'), findsOneWidget);
    });
  }

  testWidgets('una edad inválida no guarda nada', (tester) async {
    final state = await pumpProfile(tester);
    await tester.enterText(ageField(), '500');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(state.profile.age, 30);
    expect(find.text('Perfil actualizado con éxito'), findsNothing);
  });

  testWidgets('guardar una edad válida actualiza el perfil', (tester) async {
    final state = await pumpProfile(tester);
    await tester.enterText(ageField(), '45');
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(state.profile.age, 45);
    expect(StorageService().getProfile().age, 45);
    expect(find.text('Perfil actualizado con éxito'), findsOneWidget);
  });

  testWidgets('cambiar el nivel y guardar', (tester) async {
    final state = await pumpProfile(tester);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Competitivo (< 1:15 min/100m)').last);
    await tester.pumpAndSettle();
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(state.profile.level, 'competitive');
  });

  testWidgets('el dropdown ofrece los cuatro niveles', (tester) async {
    await pumpProfile(tester);
    final field = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(field.items!.map((i) => i.value),
        ['beginner', 'intermediate', 'advanced', 'competitive']);
  });

  testWidgets('conserva useMockData al guardar', (tester) async {
    final state = await pumpProfile(tester,
        profile: UserProfile(age: 25, level: 'beginner', useMockData: true));
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    expect(state.profile.useMockData, isTrue);
  });

  testWidgets('indica que solo usa datos reales', (tester) async {
    await pumpProfile(tester);
    expect(find.textContaining('Modo Estricto'), findsOneWidget);
  });
}
