import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/swim_session.dart';
import 'auth_service.dart';

/// Cliente HTTP de coswim-backend (ver backend/README.md). La app nunca
/// habla directo con Postgres — todo pasa por esta API.
///
/// URL configurable en build/run con:
///   flutter run --dart-define=BACKEND_URL=https://tu-app.up.railway.app
class BackendService {
  static const String _baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:3000',
  );

  final AuthService _auth;
  final http.Client _client;

  /// [auth] y [client] solo se pasan en tests; por defecto se usan el
  /// AuthService real y un http.Client nuevo.
  BackendService({AuthService? auth, http.Client? client})
      : _auth = auth ?? AuthService(),
        _client = client ?? http.Client();

  /// Canjea el idToken de Google por el JWT propio del backend y lo guarda.
  /// Devuelve el email del usuario autenticado.
  Future<String> signInWithGoogleIdToken(String idToken) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (res.statusCode != 200) {
      throw Exception('Login falló (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['token'] as String;
    final email = (data['user'] as Map<String, dynamic>)['email'] as String;
    await _auth.saveSession(token: token, email: email);
    return email;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.backendToken;
    if (token == null) throw Exception('No hay sesión iniciada');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Trae el historial de sesiones ya guardado en la base de datos.
  Future<List<SwimSession>> fetchSessions() async {
    final res = await _client.get(
      Uri.parse('$_baseUrl/sessions'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('No se pudo leer /sessions (${res.statusCode})');
    }
    return _parseSessions(res.body);
  }

  /// Sube (upsert) las sesiones leídas de Health Connect y devuelve el
  /// historial completo ya actualizado desde la base de datos.
  Future<List<SwimSession>> syncSessions(List<SwimSession> sessions) async {
    final res = await _client.post(
      Uri.parse('$_baseUrl/sessions/sync'),
      headers: await _authHeaders(),
      body: jsonEncode({'sessions': sessions.map((s) => s.toJson()).toList()}),
    );
    if (res.statusCode != 200) {
      throw Exception('No se pudo sincronizar sesiones (${res.statusCode})');
    }
    return _parseSessions(res.body);
  }

  List<SwimSession> _parseSessions(String body) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final list = data['sessions'] as List<dynamic>;
    return list
        .map((e) => SwimSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
