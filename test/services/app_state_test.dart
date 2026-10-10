import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/services/app_state.dart';
import 'package:coswim/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('estado inicial (antes de init)', () {
    final state = AppState(
      health: StubHealthService(),
      auth: FakeAuthService(),
      backend: FakeBackendService(),
    );

    test('perfil por defecto', () => expect(state.profile.age, 22));
    test('sin sesiones', () => expect(state.sessions, isEmpty));
    test('lastSession es null', () => expect(state.lastSession, isNull));
    test('no está cargando', () => expect(state.isLoading, isFalse));
    test('sin error', () => expect(state.errorMessage, isNull));
    test('permisos desconocidos', () => expect(state.permissionsGranted, isNull));
    test('sin sesión de Google', () => expect(state.isSignedIn, isFalse));
  });

  group('init', () {
    test('carga el perfil guardado y las sesiones de Health Connect', () async {
      final health = StubHealthService(sessions: [buildSession(id: 'a'), buildSession(id: 'b')]);
      final state = await buildAppState(
        health: health,
        profile: UserProfile(age: 35, level: 'advanced', useMockData: false),
        signedIn: false,
      );
      expect(state.profile.age, 35);
      expect(state.profile.level, 'advanced');
      expect(state.sessions.map((s) => s.id), ['a', 'b']);
      expect(state.lastSession!.id, 'a');
      expect(state.isLoading, isFalse);
      expect(health.lastProfile!.level, 'advanced');
    });

    test('refleja si ya había sesión de Google', () async {
      final state = await buildAppState(signedIn: true);
      expect(state.isSignedIn, isTrue);
    });

    test('notifica a los listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState(
        storage: StorageService(),
        health: StubHealthService(),
        auth: FakeAuthService(),
        backend: FakeBackendService(),
      );
      var notifications = 0;
      state.addListener(() => notifications++);
      await state.init();
      expect(notifications, greaterThanOrEqualTo(3));
    });
  });

  group('refreshData', () {
    test('guarda en caché lo leído de Health Connect', () async {
      final state = await buildAppState(sessions: [buildSession(id: 'cache-me')], signedIn: false);
      expect(StorageService().getSessions().map((s) => s.id), ['cache-me']);
      expect(state.errorMessage, isNull);
    });

    test('si Health Connect falla deja error, vacía sesiones y caché', () async {
      final health = StubHealthService(fetchError: Exception('HC caído'));
      final state = await buildAppState(health: health, signedIn: false);
      expect(state.errorMessage, contains('HC caído'));
      expect(state.sessions, isEmpty);
      expect(StorageService().getSessions(), isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('con sesión iniciada sincroniza y usa lo que devuelve el backend', () async {
      final backend = FakeBackendService(syncResult: [buildSession(id: 'del-servidor')]);
      final state = await buildAppState(
        sessions: [buildSession(id: 'local')],
        backend: backend,
        signedIn: true,
      );
      expect(backend.lastSynced!.map((s) => s.id), ['local']);
      expect(state.sessions.map((s) => s.id), ['del-servidor']);
      expect(StorageService().getSessions().map((s) => s.id), ['del-servidor']);
    });

    test('sin sesión iniciada no llama al backend', () async {
      final backend = FakeBackendService();
      await buildAppState(sessions: [buildSession()], backend: backend, signedIn: false);
      expect(backend.lastSynced, isNull);
    });

    test('si el backend falla se queda con lo de Health Connect', () async {
      final state = await buildAppState(
        sessions: [buildSession(id: 'hc')],
        backend: FakeBackendService(syncError: Exception('sin red')),
        signedIn: true,
      );
      expect(state.sessions.map((s) => s.id), ['hc']);
      expect(state.errorMessage, isNull);
    });

    test('un refresh exitoso limpia el error anterior', () async {
      final health = StubHealthService(fetchError: Exception('x'));
      final state = await buildAppState(health: health, signedIn: false);
      expect(state.errorMessage, isNotNull);
      health.fetchError = null;
      health.sessions = [buildSession()];
      await state.refreshData();
      expect(state.errorMessage, isNull);
      expect(state.sessions, hasLength(1));
    });
  });

  group('signInWithGoogle', () {
    test('canjea el idToken, marca la sesión y refresca', () async {
      final backend = FakeBackendService();
      final health = StubHealthService();
      final state = await buildAppState(
        signedIn: false,
        auth: FakeAuthService(idToken: 'tok'),
        backend: backend,
        health: health,
      );
      final callsBefore = health.fetchCalls;
      expect(await state.signInWithGoogle(), isTrue);
      expect(state.isSignedIn, isTrue);
      expect(backend.lastIdToken, 'tok');
      expect(health.fetchCalls, callsBefore + 1);
    });

    test('si el usuario cancela devuelve false sin error', () async {
      final state = await buildAppState(signedIn: false, auth: FakeAuthService(idToken: null));
      expect(await state.signInWithGoogle(), isFalse);
      expect(state.isSignedIn, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('si el backend rechaza el login devuelve false con mensaje', () async {
      final state = await buildAppState(
        signedIn: false,
        backend: FakeBackendService(loginError: Exception('401')),
      );
      expect(await state.signInWithGoogle(), isFalse);
      expect(state.isSignedIn, isFalse);
      expect(state.errorMessage, startsWith('No se pudo iniciar sesión'));
    });

    test('si Google lanza error devuelve false con mensaje', () async {
      final state = await buildAppState(
        signedIn: false,
        auth: FakeAuthService(signInError: Exception('sin Play Services')),
      );
      expect(await state.signInWithGoogle(), isFalse);
      expect(state.errorMessage, contains('sin Play Services'));
    });
  });

  test('signOut cierra la sesión', () async {
    final auth = FakeAuthService(signedIn: true);
    final state = await buildAppState(auth: auth);
    await state.signOut();
    expect(state.isSignedIn, isFalse);
    expect(auth.signOutCalls, 1);
  });

  group('requestPermissions', () {
    test('concedidos', () async {
      final state = await buildAppState(health: StubHealthService(permissionResult: true));
      expect(await state.requestPermissions(), isTrue);
      expect(state.permissionsGranted, isTrue);
    });

    test('denegados', () async {
      final state = await buildAppState(health: StubHealthService(permissionResult: false));
      expect(await state.requestPermissions(), isFalse);
      expect(state.permissionsGranted, isFalse);
    });
  });

  test('updateProfile guarda el perfil y vuelve a leer con él', () async {
    final health = StubHealthService();
    final state = await buildAppState(health: health, signedIn: false);
    await state.updateProfile(UserProfile(age: 50, level: 'competitive', useMockData: false));
    expect(state.profile.age, 50);
    expect(StorageService().getProfile().level, 'competitive');
    expect(health.lastProfile!.age, 50);
  });

  group('fetchRawJsonData', () {
    test('devuelve los puntos crudos y pasa el rango', () async {
      final health = StubHealthService(rawPoints: [rawPoint('HEART_RATE', kStart)]);
      final state = await buildAppState(health: health);
      final points = await state.fetchRawJsonData(days: const Duration(days: 7));
      expect(points.single['type'], 'HEART_RATE');
      expect(health.lastRawDays, const Duration(days: 7));
    });

    test('si falla devuelve vacío y deja el error', () async {
      final health = StubHealthService(rawError: Exception('boom'));
      final state = await buildAppState(health: health);
      expect(await state.fetchRawJsonData(), isEmpty);
      expect(state.errorMessage, contains('datos crudos'));
    });
  });

  test('exportFullDumpJson devuelve el volcado del servicio', () async {
    final state = await buildAppState(health: StubHealthService(dump: '{"ok":1}'));
    expect(await state.exportFullDumpJson(), '{"ok":1}');
  });

  group('installHealthConnect', () {
    test('delega en HealthService', () async {
      final health = StubHealthService();
      final state = await buildAppState(health: health);
      await state.installHealthConnect();
      expect(health.installCalls, 1);
      expect(state.errorMessage, isNull);
    });

    test('si falla deja un mensaje de error', () async {
      final state = await buildAppState(
          health: StubHealthService(installError: Exception('sin Play Store')));
      await state.installHealthConnect();
      expect(state.errorMessage, contains('Play Store'));
    });
  });
}
