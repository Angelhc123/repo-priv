import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:coswim/services/auth_service.dart';
import 'package:coswim/services/backend_service.dart';

import '../helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  AuthService authWith(Map<String, String> stored) {
    FlutterSecureStorage.setMockInitialValues(stored);
    return AuthService.forTesting();
  }

  BackendService backend(AuthService auth, http.Response Function(http.Request) handler) {
    requests = [];
    return BackendService(
      auth: auth,
      client: MockClient((req) async {
        requests.add(req);
        return handler(req);
      }),
    );
  }

  String sessionsBody(int n) => jsonEncode({
        'sessions': [for (var i = 0; i < n; i++) buildSession(id: 'b$i').toJson()],
      });

  group('signInWithGoogleIdToken', () {
    test('manda el idToken a /auth/google y guarda el JWT', () async {
      final auth = authWith({});
      final service = backend(
        auth,
        (_) => http.Response(
            jsonEncode({'token': 'jwt-1', 'user': {'email': 'ana@example.com'}}), 200),
      );

      final email = await service.signInWithGoogleIdToken('google-id');

      expect(email, 'ana@example.com');
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/auth/google');
      expect(jsonDecode(requests.single.body), {'idToken': 'google-id'});
      expect(requests.single.headers['Content-Type'], startsWith('application/json'));
      expect(await auth.backendToken, 'jwt-1');
      expect(await auth.userEmail, 'ana@example.com');
    });

    test('respuesta distinta de 200 lanza excepción con el código', () async {
      final service = backend(authWith({}), (_) => http.Response('{"error":"x"}', 401));
      await expectLater(
        service.signInWithGoogleIdToken('malo'),
        throwsA(predicate((e) => e.toString().contains('401'))),
      );
    });

    test('un login fallido no guarda token', () async {
      final auth = authWith({});
      final service = backend(auth, (_) => http.Response('nope', 500));
      await expectLater(service.signInWithGoogleIdToken('x'), throwsException);
      expect(await auth.backendToken, isNull);
    });
  });

  group('fetchSessions', () {
    test('sin sesión iniciada lanza excepción sin hacer la request', () async {
      final service = backend(authWith({}), (_) => http.Response('{}', 200));
      await expectLater(service.fetchSessions(), throwsException);
      expect(requests, isEmpty);
    });

    test('manda el JWT como Bearer y parsea las sesiones', () async {
      final service = backend(
          authWith({'backend_jwt': 'jwt-abc'}), (_) => http.Response(sessionsBody(2), 200));
      final sessions = await service.fetchSessions();
      expect(sessions.map((s) => s.id), ['b0', 'b1']);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/sessions');
      expect(requests.single.headers['Authorization'], 'Bearer jwt-abc');
    });

    test('lista vacía del servidor da lista vacía', () async {
      final service = backend(authWith({'backend_jwt': 't'}),
          (_) => http.Response(jsonEncode({'sessions': []}), 200));
      expect(await service.fetchSessions(), isEmpty);
    });

    test('error del servidor lanza excepción', () async {
      final service =
          backend(authWith({'backend_jwt': 't'}), (_) => http.Response('caído', 503));
      await expectLater(
        service.fetchSessions(),
        throwsA(predicate((e) => e.toString().contains('503'))),
      );
    });
  });

  group('syncSessions', () {
    test('sube las sesiones a /sessions/sync y devuelve el historial', () async {
      final service = backend(
          authWith({'backend_jwt': 'jwt-sync'}), (_) => http.Response(sessionsBody(3), 200));
      final local = [buildSession(id: 'local-1'), buildSession(id: 'local-2')];

      final merged = await service.syncSessions(local);

      expect(merged.length, 3);
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/sessions/sync');
      expect(requests.single.headers['Authorization'], 'Bearer jwt-sync');
      final sent = jsonDecode(requests.single.body)['sessions'] as List;
      expect(sent.map((s) => s['id']), ['local-1', 'local-2']);
    });

    test('las sesiones viajan con la forma de SwimSession.toJson', () async {
      final service = backend(
          authWith({'backend_jwt': 't'}), (_) => http.Response(sessionsBody(0), 200));
      final session = buildSession(id: 'forma');
      await service.syncSessions([session]);
      final sent = (jsonDecode(requests.single.body)['sessions'] as List).single;
      expect(sent, jsonDecode(jsonEncode(session.toJson())));
    });

    test('sin sesión iniciada lanza excepción', () async {
      final service = backend(authWith({}), (_) => http.Response('{}', 200));
      await expectLater(service.syncSessions([]), throwsException);
    });

    test('error del servidor lanza excepción', () async {
      final service =
          backend(authWith({'backend_jwt': 't'}), (_) => http.Response('x', 500));
      await expectLater(service.syncSessions([]), throwsException);
    });
  });

  test('constructor por defecto no falla', () {
    expect(BackendService(), isA<BackendService>());
  });
}
