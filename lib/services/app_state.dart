import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../models/user_profile.dart';
import '../models/swim_session.dart';
import 'storage_service.dart';
import 'health_service.dart';
import 'fake_health_service.dart';
import 'auth_service.dart';
import 'backend_service.dart';

// FAKE_HEALTH: entorno de prueba para correr la app en el escritorio (Linux/
// web) sin teléfono ni Mi Fitness. Activar con:
//   flutter run -d linux --dart-define=FAKE_HEALTH=true
// Por defecto en false, así una corrida normal nunca lo toca.
// Para eliminar el simulador: borrar fake_health_service.dart y las líneas
// marcadas "FAKE_HEALTH" en este archivo. Nada más depende de esto.
const bool _kFakeHealth = bool.fromEnvironment('FAKE_HEALTH');

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final HealthService _health = HealthService();
  final FakeHealthService _fakeHealth = FakeHealthService(); // FAKE_HEALTH
  final AuthService _auth = AuthService();
  final BackendService _backend = BackendService();

  UserProfile _profile = UserProfile.defaultProfile();
  List<SwimSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  // null = unknown, true = granted, false = denied/failed
  bool? _permissionsGranted;
  bool _isSignedIn = false;

  UserProfile get profile => _profile;
  List<SwimSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool? get permissionsGranted => _permissionsGranted;
  bool get isSignedIn => _isSignedIn;

  SwimSession? get lastSession => _sessions.isNotEmpty ? _sessions.first : null;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _storage.init();
    _profile = _storage.getProfile();
    _sessions = _storage.getSessions();
    _isSignedIn = await _auth.isSignedIn;

    // Do NOT call requestPermissions() here — this runs before runApp() so
    // the Android Activity doesn't exist yet and the permission dialog crashes.
    // Permissions are requested from the UI layer after the first frame renders.
    await refreshData();
  }

  /// Dispara el selector de cuenta de Google, canjea el idToken por el JWT
  /// propio del backend (ver backend_service.dart) y, si todo sale bien,
  /// sincroniza y trae el historial desde la base de datos.
  Future<bool> signInWithGoogle() async {
    _errorMessage = null;
    try {
      final idToken = await _auth.signInWithGoogle();
      if (idToken == null) return false; // el usuario canceló el selector

      await _backend.signInWithGoogleIdToken(idToken);
      _isSignedIn = true;
      notifyListeners();

      await refreshData();
      return true;
    } catch (e) {
      _errorMessage = "No se pudo iniciar sesión: $e";
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _isSignedIn = false;
    notifyListeners();
  }

  /// Triggers the Health Connect permission dialog. Returns true if granted.
  Future<bool> requestPermissions() async {
    _permissionsGranted =
        _kFakeHealth ? true : await _health.requestPermissions(); // FAKE_HEALTH
    notifyListeners();
    return _permissionsGranted == true;
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    _profile = newProfile;
    await _storage.saveProfile(_profile);
    notifyListeners();
    await refreshData();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = _kFakeHealth // FAKE_HEALTH
          ? await _fakeHealth.fetchSwimSessions(_profile)
          : await _health.fetchSwimSessions(_profile);
      _sessions = fetched;
      await _storage.saveSessions(_sessions);
    } catch (e) {
      _errorMessage = "No se pudieron obtener datos de Health Connect: $e";
      _sessions = [];
      await _storage.saveSessions([]);
    }

    // Si hay sesión de Google activa, el backend pasa a ser la fuente de
    // verdad: se sube lo que se acaba de leer de Health Connect y se
    // reemplaza _sessions con lo que devuelve la base de datos (incluye
    // sesiones subidas antes, aunque Health Connect ya no las tenga a mano).
    // Si el backend no responde (sin red, servidor caído), nos quedamos con
    // lo leído arriba de Health Connect / el caché local — nunca se bloquea
    // la app por esto.
    if (_isSignedIn) {
      try {
        final merged = await _backend.syncSessions(_sessions);
        _sessions = merged;
        await _storage.saveSessions(_sessions);
      } catch (e) {
        // ignore: avoid_print
        print("No se pudo sincronizar con el backend: $e");
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchRawJsonData(
      {Duration days = const Duration(days: 30)}) async {
    try {
      return _kFakeHealth // FAKE_HEALTH
          ? await _fakeHealth.fetchRawHealthData(days: days)
          : await _health.fetchRawHealthData(days: days);
    } catch (e) {
      _errorMessage = "Error al leer datos crudos de Health Connect: $e";
      notifyListeners();
      return [];
    }
  }

  /// Texto completo (JSON legible) con todo lo que Health Connect pueda dar
  /// por sesión, para exportar a un .txt y mandarlo a revisar — ver
  /// exportFullDumpJson en health_service.dart.
  Future<String> exportFullDumpJson({Duration days = const Duration(days: 1000)}) async {
    return _kFakeHealth // FAKE_HEALTH
        ? await _fakeHealth.exportFullDumpJson(days: days)
        : await _health.exportFullDumpJson(days: days);
  }

  Future<void> installHealthConnect() async {
    if (_kFakeHealth) return; // FAKE_HEALTH
    try {
      await Health().installHealthConnect();
    } catch (e) {
      _errorMessage =
          "No se pudo abrir la Play Store para instalar Health Connect: $e";
      notifyListeners();
    }
  }
}
