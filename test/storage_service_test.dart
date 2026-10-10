import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coswim/services/storage_service.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/models/swim_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageService', () {
    late StorageService storage;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();
    });

    test('getProfile devuelve el perfil por defecto si no hay nada guardado', () {
      final profile = storage.getProfile();
      expect(profile.age, 22);
      expect(profile.level, 'beginner');
      expect(profile.useMockData, false);
    });

    test('getSessions devuelve lista vacía si no hay nada guardado', () {
      expect(storage.getSessions(), isEmpty);
    });

    test('saveProfile + getProfile hacen round-trip', () async {
      final profile = UserProfile(age: 30, level: 'advanced', useMockData: true);
      final ok = await storage.saveProfile(profile);
      expect(ok, true);
      final restored = storage.getProfile();
      expect(restored.age, 30);
      expect(restored.level, 'advanced');
      expect(restored.useMockData, true);
    });

    test('saveSessions + getSessions hacen round-trip', () async {
      final session = SwimSession(
        id: 'x1',
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 30),
        distance: 1000,
        calories: 200,
        heartRateSeries: const [],
      );
      final ok = await storage.saveSessions([session]);
      expect(ok, true);
      final restored = storage.getSessions();
      expect(restored.length, 1);
      expect(restored.first.id, 'x1');
      expect(restored.first.distance, 1000);
    });

    test('saveSessions con lista vacía deja getSessions vacío', () async {
      await storage.saveSessions([]);
      expect(storage.getSessions(), isEmpty);
    });
  });
}
