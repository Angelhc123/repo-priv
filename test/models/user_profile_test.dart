import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/user_profile.dart';

void main() {
  group('UserProfile.defaultProfile', () {
    test('tiene edad 22', () {
      expect(UserProfile.defaultProfile().age, 22);
    });

    test('tiene nivel principiante', () {
      expect(UserProfile.defaultProfile().level, 'beginner');
    });

    test('no usa datos simulados', () {
      expect(UserProfile.defaultProfile().useMockData, isFalse);
    });
  });

  group('UserProfile.copyWith', () {
    final base = UserProfile(age: 30, level: 'advanced', useMockData: false);

    test('sin argumentos devuelve una copia idéntica', () {
      final copy = base.copyWith();
      expect(copy.age, 30);
      expect(copy.level, 'advanced');
      expect(copy.useMockData, isFalse);
      expect(identical(copy, base), isFalse);
    });

    test('cambia solo la edad', () {
      final copy = base.copyWith(age: 45);
      expect(copy.age, 45);
      expect(copy.level, 'advanced');
    });

    test('cambia solo el nivel', () {
      final copy = base.copyWith(level: 'competitive');
      expect(copy.level, 'competitive');
      expect(copy.age, 30);
    });

    test('cambia solo useMockData', () {
      expect(base.copyWith(useMockData: true).useMockData, isTrue);
    });

    test('cambia todos los campos a la vez', () {
      final copy = base.copyWith(age: 18, level: 'beginner', useMockData: true);
      expect([copy.age, copy.level, copy.useMockData], [18, 'beginner', true]);
    });
  });

  group('UserProfile JSON', () {
    test('toJson incluye las tres claves', () {
      final json = UserProfile(age: 40, level: 'intermediate', useMockData: true).toJson();
      expect(json, {'age': 40, 'level': 'intermediate', 'useMockData': true});
    });

    test('fromJson lee todos los campos', () {
      final p = UserProfile.fromJson({'age': 55, 'level': 'competitive', 'useMockData': true});
      expect([p.age, p.level, p.useMockData], [55, 'competitive', true]);
    });

    test('fromJson con mapa vacío usa los valores por defecto', () {
      final p = UserProfile.fromJson({});
      expect([p.age, p.level, p.useMockData], [22, 'beginner', false]);
    });

    test('fromJson con nulos usa los valores por defecto', () {
      final p = UserProfile.fromJson({'age': null, 'level': null, 'useMockData': null});
      expect([p.age, p.level, p.useMockData], [22, 'beginner', false]);
    });

    test('fromJson con solo la edad completa el resto por defecto', () {
      final p = UserProfile.fromJson({'age': 33});
      expect([p.age, p.level, p.useMockData], [33, 'beginner', false]);
    });

    test('round-trip toJson → fromJson conserva los datos', () {
      final original = UserProfile(age: 27, level: 'advanced', useMockData: true);
      final restored = UserProfile.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
    });
  });
}
