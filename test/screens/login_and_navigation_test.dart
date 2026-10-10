import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/main.dart';
import 'package:coswim/screens/charts_screen.dart';
import 'package:coswim/screens/dashboard_screen.dart';
import 'package:coswim/screens/history_screen.dart';
import 'package:coswim/screens/login_screen.dart';
import 'package:coswim/screens/main_navigation.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

/// AuthService cuyo signIn queda pendiente hasta completar [completer].
class _SlowAuth extends FakeAuthService {
  final completer = Completer<String?>();

  @override
  Future<String?> signInWithGoogle() => completer.future;
}

void main() {
  setUpAll(initSpanishDates);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('LoginScreen', () {
    testWidgets('muestra la marca y el botón de Google', (tester) async {
      final state = await buildAppState(signedIn: false);
      await pumpScreen(tester, LoginScreen(appState: state, onSignedIn: () {}));
      expect(find.text('CoSwim'), findsOneWidget);
      expect(find.text('Iniciar sesión con Google'), findsOneWidget);
    });

    testWidgets('login exitoso llama a onSignedIn', (tester) async {
      var called = 0;
      final state = await buildAppState(signedIn: false);
      await pumpScreen(tester, LoginScreen(appState: state, onSignedIn: () => called++));
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pumpAndSettle();
      expect(called, 1);
    });

    testWidgets('muestra el spinner mientras espera a Google', (tester) async {
      final auth = _SlowAuth();
      final state = await buildAppState(signedIn: false, auth: auth);
      await pumpScreen(tester, LoginScreen(appState: state, onSignedIn: () {}));
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Iniciar sesión con Google'), findsNothing);
      auth.completer.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Iniciar sesión con Google'), findsOneWidget);
    });

    testWidgets('si el usuario cancela muestra el mensaje genérico', (tester) async {
      var called = 0;
      final state = await buildAppState(signedIn: false, auth: FakeAuthService(idToken: null));
      await pumpScreen(tester, LoginScreen(appState: state, onSignedIn: () => called++));
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pumpAndSettle();
      expect(find.text('No se pudo iniciar sesión. Intenta de nuevo.'), findsOneWidget);
      expect(called, 0);
    });

    testWidgets('si el backend falla muestra el error de AppState', (tester) async {
      final state = await buildAppState(
          signedIn: false, backend: FakeBackendService(loginError: Exception('servidor caído')));
      await pumpScreen(tester, LoginScreen(appState: state, onSignedIn: () {}));
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pumpAndSettle();
      expect(find.textContaining('servidor caído'), findsOneWidget);
    });

    testWidgets('si la pantalla se desmonta durante el login no falla', (tester) async {
      final auth = _SlowAuth();
      final state = await buildAppState(signedIn: false, auth: auth);
      await pumpScreen(tester, LoginScreen(appState: state, onSignedIn: () {}));
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      auth.completer.complete('tarde');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('MainNavigation', () {
    Future<void> pumpNav(WidgetTester tester) async {
      final state = await buildAppState(sessions: buildHistory(3), signedIn: false);
      await pumpScreen(tester, MainNavigation(appState: state), size: const Size(1400, 4000));
      await tester.pumpAndSettle();
    }

    testWidgets('tiene las tres pestañas', (tester) async {
      await pumpNav(tester);
      expect(find.text('Entrenamientos'), findsOneWidget);
      expect(find.text('Progreso'), findsOneWidget);
      expect(find.text('Datos'), findsOneWidget);
    });

    testWidgets('monta las tres pantallas en un IndexedStack', (tester) async {
      await pumpNav(tester);
      expect(find.byType(IndexedStack), findsOneWidget);
      expect(find.byType(HistoryScreen), findsOneWidget);
      expect(find.byType(ChartsScreen), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('arranca en Entrenamientos', (tester) async {
      await pumpNav(tester);
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
    });

    for (final (label, index) in const [('Progreso', 1), ('Datos', 2), ('Entrenamientos', 0)]) {
      testWidgets('tocar "$label" muestra la pestaña $index', (tester) async {
        await pumpNav(tester);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, index);
        expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, index);
      });
    }

    testWidgets('cambiar de pestaña no recrea el dashboard', (tester) async {
      await pumpNav(tester);
      final before = tester.state(find.byType(DashboardScreen));
      await tester.tap(find.text('Datos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Progreso'));
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(DashboardScreen)), before), isTrue);
    });
  });

  group('MyApp / AuthGate', () {
    testWidgets('sin sesión muestra el login', (tester) async {
      final state = await buildAppState(signedIn: false);
      await tester.pumpWidget(MyApp(appState: state));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MainNavigation), findsNothing);
    });

    testWidgets('con sesión muestra la navegación principal', (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = await buildAppState(signedIn: true);
      await tester.pumpWidget(MyApp(appState: state));
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigation), findsOneWidget);
    });

    testWidgets('al iniciar sesión pasa del login a la app', (tester) async {
      tester.view.physicalSize = const Size(1400, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = await buildAppState(signedIn: false);
      await tester.pumpWidget(MyApp(appState: state));
      await tester.tap(find.text('Iniciar sesión con Google'));
      await tester.pumpAndSettle();
      expect(find.byType(MainNavigation), findsOneWidget);
    });

    testWidgets('usa el tema oscuro sin banner de debug', (tester) async {
      final state = await buildAppState(signedIn: false);
      await tester.pumpWidget(MyApp(appState: state));
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.title, 'CoSwim');
      expect(app.debugShowCheckedModeBanner, isFalse);
      expect(app.theme!.brightness, Brightness.dark);
      expect(app.theme!.colorScheme.primary, const Color(0xFF64FFDA));
    });
  });
}
