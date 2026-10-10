import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coswim/services/storage_service.dart';

import '../helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<StorageService> storageWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final storage = StorageService();
    await storage.init();
    return storage;
  }

  test('StorageService() es un singleton', () {
    expect(identical(StorageService(), StorageService()), isTrue);
  });

  test('perfil con JSON corrupto vuelve al perfil por defecto', () async {
    final storage = await storageWith({'user_profile': '{no es json'});
    expect(storage.getProfile().age, 22);
  });

  test('perfil guardado como lista vuelve al perfil por defecto', () async {
    final storage = await storageWith({'user_profile': '[1, 2, 3]'});
    expect(storage.getProfile().level, 'beginner');
  });

  test('perfil con campos parciales completa los faltantes', () async {
    final storage = await storageWith({'user_profile': '{"age": 41}'});
    final p = storage.getProfile();
    expect(p.age, 41);
    expect(p.level, 'beginner');
  });

  test('una sesión corrupta en caché devuelve lista vacía', () async {
    final storage = await storageWith({
      'swim_sessions': ['{"id": "ok"', 'basura'],
    });
    expect(storage.getSessions(), isEmpty);
  });

  test('sesión sin campos obligatorios devuelve lista vacía', () async {
    final storage = await storageWith({
      'swim_sessions': ['{"id": "x"}'],
    });
    expect(storage.getSessions(), isEmpty);
  });

  test('conserva el orden de varias sesiones', () async {
    final storage = await storageWith({});
    await storage.saveSessions([buildSession(id: 'c'), buildSession(id: 'a'), buildSession(id: 'b')]);
    expect(storage.getSessions().map((s) => s.id), ['c', 'a', 'b']);
  });

  test('las series completas sobreviven al caché', () async {
    final storage = await storageWith({});
    final original = buildSession();
    await storage.saveSessions([original]);
    final restored = storage.getSessions().single;
    expect(restored.heartRateSeries.length, original.heartRateSeries.length);
    expect(restored.calorieSeries.length, original.calorieSeries.length);
    expect(restored.stepSeries.length, original.stepSeries.length);
  });

  test('guardar de nuevo reemplaza la caché anterior', () async {
    final storage = await storageWith({});
    await storage.saveSessions([buildSession(id: 'vieja')]);
    await storage.saveSessions([buildSession(id: 'nueva')]);
    expect(storage.getSessions().map((s) => s.id), ['nueva']);
  });
}
