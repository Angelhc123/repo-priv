import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:coswim/services/auth_service.dart';

class _FakeAuthentication extends Fake implements GoogleSignInAuthentication {
  _FakeAuthentication(this.idToken);

  @override
  final String? idToken;
}

class _FakeAccount extends Fake implements GoogleSignInAccount {
  _FakeAccount(this._idToken);
  final String? _idToken;

  @override
  Future<GoogleSignInAuthentication> get authentication async => _FakeAuthentication(_idToken);
}

class _FakeGoogleSignIn extends Fake implements GoogleSignIn {
  _FakeGoogleSignIn({this.account});

  GoogleSignInAccount? account;
  int signOutCalls = 0;

  @override
  Future<GoogleSignInAccount?> signIn() async => account;

  @override
  Future<GoogleSignInAccount?> signOut() async {
    signOutCalls++;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('signInWithGoogle', () {
    test('devuelve el idToken de la cuenta elegida', () async {
      final auth = AuthService.forTesting(
          googleSignIn: _FakeGoogleSignIn(account: _FakeAccount('id-token-123')));
      expect(await auth.signInWithGoogle(), 'id-token-123');
    });

    test('devuelve null si el usuario cancela el selector', () async {
      final auth = AuthService.forTesting(googleSignIn: _FakeGoogleSignIn());
      expect(await auth.signInWithGoogle(), isNull);
    });

    test('devuelve null si Google no entrega idToken', () async {
      final auth = AuthService.forTesting(
          googleSignIn: _FakeGoogleSignIn(account: _FakeAccount(null)));
      expect(await auth.signInWithGoogle(), isNull);
    });
  });

  group('sesión del backend', () {
    test('sin nada guardado no hay token ni sesión', () async {
      final auth = AuthService.forTesting(googleSignIn: _FakeGoogleSignIn());
      expect(await auth.backendToken, isNull);
      expect(await auth.isSignedIn, isFalse);
      expect(await auth.userEmail, isNull);
    });

    test('lee un token guardado previamente', () async {
      FlutterSecureStorage.setMockInitialValues(
          {'backend_jwt': 'guardado', 'backend_user_email': 'a@b.com'});
      final auth = AuthService.forTesting(googleSignIn: _FakeGoogleSignIn());
      expect(await auth.backendToken, 'guardado');
      expect(await auth.isSignedIn, isTrue);
      expect(await auth.userEmail, 'a@b.com');
    });

    test('saveSession guarda token y email', () async {
      final auth = AuthService.forTesting(googleSignIn: _FakeGoogleSignIn());
      await auth.saveSession(token: 'jwt-nuevo', email: 'nuevo@example.com');
      expect(await auth.backendToken, 'jwt-nuevo');
      expect(await auth.userEmail, 'nuevo@example.com');
      expect(await auth.isSignedIn, isTrue);
    });

    test('saveSession persiste para una instancia nueva', () async {
      await AuthService.forTesting(googleSignIn: _FakeGoogleSignIn())
          .saveSession(token: 'persistido', email: 'p@example.com');
      final other = AuthService.forTesting(googleSignIn: _FakeGoogleSignIn());
      expect(await other.backendToken, 'persistido');
    });

    test('el token queda en caché tras la primera lectura', () async {
      FlutterSecureStorage.setMockInitialValues({'backend_jwt': 'cache'});
      final auth = AuthService.forTesting(googleSignIn: _FakeGoogleSignIn());
      expect(await auth.backendToken, 'cache');
      FlutterSecureStorage.setMockInitialValues({});
      expect(await auth.backendToken, 'cache');
    });

    test('signOut borra token, email y cierra sesión en Google', () async {
      final google = _FakeGoogleSignIn();
      final auth = AuthService.forTesting(googleSignIn: google);
      await auth.saveSession(token: 't', email: 'e@example.com');

      await auth.signOut();

      expect(google.signOutCalls, 1);
      expect(await auth.backendToken, isNull);
      expect(await auth.userEmail, isNull);
      expect(await auth.isSignedIn, isFalse);
    });
  });

  test('AuthService() es un singleton', () {
    expect(identical(AuthService(), AuthService()), isTrue);
  });

  test('forTesting crea instancias independientes del singleton', () {
    expect(identical(AuthService.forTesting(), AuthService()), isFalse);
  });
}
