import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Envuelve Google Sign-In (nunca manejamos contraseñas propias) y guarda el
/// JWT que emite coswim-backend tras canjear el idToken de Google — ver
/// POST /auth/google en backend/src/routes.js.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _keyBackendToken = "backend_jwt";
  static const _keyUserEmail = "backend_user_email";

  // Client ID de tipo "Aplicación web" (no el de tipo Android) — ver
  // backend/.env.example. Sin esto, GoogleSignIn en Android no devuelve
  // idToken, solo accessToken, y el backend no tiene audience para verificar.
  static const String _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
  );
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  String? _cachedToken;

  Future<String?> get backendToken async {
    _cachedToken ??= await _secureStorage.read(key: _keyBackendToken);
    return _cachedToken;
  }

  Future<bool> get isSignedIn async => (await backendToken) != null;

  Future<String?> get userEmail =>
      _secureStorage.read(key: _keyUserEmail);

  /// Dispara el selector de cuenta de Google y devuelve su idToken, o null
  /// si el usuario canceló. El idToken (NO el access token) es lo que el
  /// backend verifica con audience = GOOGLE_CLIENT_ID.
  Future<String?> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }

  Future<void> saveSession({required String token, required String email}) async {
    _cachedToken = token;
    await _secureStorage.write(key: _keyBackendToken, value: token);
    await _secureStorage.write(key: _keyUserEmail, value: email);
  }

  Future<void> signOut() async {
    _cachedToken = null;
    await _googleSignIn.signOut();
    await _secureStorage.delete(key: _keyBackendToken);
    await _secureStorage.delete(key: _keyUserEmail);
  }
}
