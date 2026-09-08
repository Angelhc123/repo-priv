import 'package:flutter/material.dart';
import 'package:health/health.dart';
import '../models/user_profile.dart';
import '../models/swim_session.dart';
import 'storage_service.dart';
import 'health_service.dart';

class AppState extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final HealthService _health = HealthService();

  UserProfile _profile = UserProfile.defaultProfile();
  List<SwimSession> _sessions = [];
  bool _isLoading = false;
  String? _errorMessage;
  // null = unknown, true = granted, false = denied/failed
  bool? _permissionsGranted;

  UserProfile get profile => _profile;
  List<SwimSession> get sessions => _sessions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool? get permissionsGranted => _permissionsGranted;

  SwimSession? get lastSession => _sessions.isNotEmpty ? _sessions.first : null;

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _storage.init();
    _profile = _storage.getProfile();
    _sessions = _storage.getSessions();

    // Do NOT call requestPermissions() here — this runs before runApp() so
    // the Android Activity doesn't exist yet and the permission dialog crashes.
    // Permissions are requested from the UI layer after the first frame renders.
    await refreshData();
  }

  /// Triggers the Health Connect permission dialog. Returns true if granted.
  Future<bool> requestPermissions() async {
    _permissionsGranted = await _health.requestPermissions();
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
      final fetched = await _health.fetchSwimSessions(_profile);
      _sessions = fetched;
      await _storage.saveSessions(_sessions);
    } catch (e) {
      _errorMessage = "No se pudieron obtener datos de Health Connect: $e";
      _sessions = [];
      await _storage.saveSessions([]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> fetchRawJsonData(
      {Duration days = const Duration(days: 30)}) async {
    try {
      return await _health.fetchRawHealthData(days: days);
    } catch (e) {
      _errorMessage = "Error al leer datos crudos de Health Connect: $e";
      notifyListeners();
      return [];
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await Health().installHealthConnect();
    } catch (e) {
      _errorMessage =
          "No se pudo abrir la Play Store para instalar Health Connect: $e";
      notifyListeners();
    }
  }
}
