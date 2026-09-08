import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_profile.dart';
import '../models/swim_session.dart';

class StorageService {
  static const String _keyProfile = "user_profile";
  static const String _keySessions = "swim_sessions";

  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get profile, fallback to default
  UserProfile getProfile() {
    if (_prefs == null) return UserProfile.defaultProfile();
    final jsonStr = _prefs!.getString(_keyProfile);
    if (jsonStr == null) return UserProfile.defaultProfile();
    try {
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      return UserProfile.fromJson(map);
    } catch (_) {
      return UserProfile.defaultProfile();
    }
  }

  /// Save profile
  Future<bool> saveProfile(UserProfile profile) async {
    if (_prefs == null) return false;
    final jsonStr = json.encode(profile.toJson());
    return await _prefs!.setString(_keyProfile, jsonStr);
  }

  /// Get cached sessions
  List<SwimSession> getSessions() {
    if (_prefs == null) return [];
    final list = _prefs!.getStringList(_keySessions);
    if (list == null) return [];
    try {
      return list.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return SwimSession.fromJson(map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save sessions cache
  Future<bool> saveSessions(List<SwimSession> sessions) async {
    if (_prefs == null) return false;
    final list = sessions.map((s) => json.encode(s.toJson())).toList();
    return await _prefs!.setStringList(_keySessions, list);
  }
}
