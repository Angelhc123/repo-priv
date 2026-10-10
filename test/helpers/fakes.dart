import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/services/app_state.dart';
import 'package:coswim/services/auth_service.dart';
import 'package:coswim/services/backend_service.dart';
import 'package:coswim/services/health_service.dart';
import 'package:coswim/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// HealthService configurable: qué sesiones/datos crudos devuelve y si falla.
class StubHealthService extends Fake implements HealthService {
  List<SwimSession> sessions;
  List<Map<String, dynamic>> rawPoints;
  String dump;
  bool permissionResult;
  Object? fetchError;
  Object? rawError;
  Object? installError;
  int fetchCalls = 0;
  int rawCalls = 0;
  int permissionCalls = 0;
  int installCalls = 0;
  Duration? lastRawDays;
  UserProfile? lastProfile;

  StubHealthService({
    this.sessions = const [],
    this.rawPoints = const [],
    this.dump = '{"sessions": []}',
    this.permissionResult = true,
    this.fetchError,
    this.rawError,
    this.installError,
  });

  @override
  Future<bool> requestPermissions() async {
    permissionCalls++;
    return permissionResult;
  }

  @override
  Future<List<SwimSession>> fetchSwimSessions(UserProfile profile,
      {Duration days = const Duration(days: 1000)}) async {
    fetchCalls++;
    lastProfile = profile;
    if (fetchError != null) throw fetchError!;
    return List.of(sessions);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRawHealthData(
      {Duration days = const Duration(days: 1000)}) async {
    rawCalls++;
    lastRawDays = days;
    if (rawError != null) throw rawError!;
    return List.of(rawPoints);
  }

  @override
  Future<String> exportFullDumpJson({Duration days = const Duration(days: 1000)}) async => dump;

  @override
  Future<void> installHealthConnect() async {
    installCalls++;
    if (installError != null) throw installError!;
  }
}

class FakeAuthService extends Fake implements AuthService {
  bool signedIn;
  String? idToken;
  Object? signInError;
  int signOutCalls = 0;

  FakeAuthService({this.signedIn = false, this.idToken = 'id-token', this.signInError});

  @override
  Future<bool> get isSignedIn async => signedIn;

  @override
  Future<String?> signInWithGoogle() async {
    if (signInError != null) throw signInError!;
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedIn = false;
  }
}

class FakeBackendService extends Fake implements BackendService {
  List<SwimSession>? syncResult;
  Object? syncError;
  Object? loginError;
  List<SwimSession>? lastSynced;
  String? lastIdToken;

  FakeBackendService({this.syncResult, this.syncError, this.loginError});

  @override
  Future<String> signInWithGoogleIdToken(String idToken) async {
    lastIdToken = idToken;
    if (loginError != null) throw loginError!;
    return 'nadador@example.com';
  }

  @override
  Future<List<SwimSession>> syncSessions(List<SwimSession> sessions) async {
    lastSynced = sessions;
    if (syncError != null) throw syncError!;
    return syncResult ?? sessions;
  }
}

/// `Health` del paquete health sin canal nativo: devuelve [points] filtrando
/// por tipo, o lanza [error].
class FakeHealthPlugin extends Fake implements Health {
  List<HealthDataPoint> points;
  Object? configureError;
  Set<HealthDataType> failingTypes;
  int configureCalls = 0;

  FakeHealthPlugin({this.points = const [], this.configureError, this.failingTypes = const {}});

  @override
  Future<void> configure() async {
    configureCalls++;
    if (configureError != null) throw configureError!;
  }

  @override
  Future<List<HealthDataPoint>> getHealthDataFromTypes({
    required List<HealthDataType> types,
    required DateTime startTime,
    required DateTime endTime,
    List<RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    if (types.any(failingTypes.contains)) throw Exception('tipo no soportado');
    return points.where((p) => types.contains(p.type)).toList();
  }
}

HealthDataPoint numericPoint(HealthDataType type, DateTime from, num value,
    {int seconds = 60, HealthDataUnit unit = HealthDataUnit.COUNT}) {
  return HealthDataPoint(
    uuid: '${type.name}-${from.millisecondsSinceEpoch}',
    value: NumericHealthValue(numericValue: value),
    type: type,
    unit: unit,
    dateFrom: from,
    dateTo: from.add(Duration(seconds: seconds)),
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'com.mi.health',
    sourceName: 'Mi Fitness',
  );
}

HealthDataPoint workoutPoint(DateTime from, int seconds,
    {int? distance, int? energy, HealthWorkoutActivityType activity = HealthWorkoutActivityType.SWIMMING}) {
  return HealthDataPoint(
    uuid: 'workout-${from.millisecondsSinceEpoch}',
    value: WorkoutHealthValue(
      workoutActivityType: activity,
      totalDistance: distance,
      totalDistanceUnit: distance == null ? null : HealthDataUnit.METER,
      totalEnergyBurned: energy,
      totalEnergyBurnedUnit: energy == null ? null : HealthDataUnit.KILOCALORIE,
    ),
    type: HealthDataType.WORKOUT,
    unit: HealthDataUnit.NO_UNIT,
    dateFrom: from,
    dateTo: from.add(Duration(seconds: seconds)),
    sourcePlatform: HealthPlatformType.googleHealthConnect,
    sourceDeviceId: 'device',
    sourceId: 'com.mi.health',
    sourceName: 'Mi Fitness',
  );
}

/// AppState con dobles y SharedPreferences en memoria, ya inicializado.
Future<AppState> buildAppState({
  List<SwimSession> sessions = const [],
  List<Map<String, dynamic>> rawPoints = const [],
  UserProfile? profile,
  bool signedIn = true,
  StubHealthService? health,
  FakeAuthService? auth,
  FakeBackendService? backend,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = StorageService();
  await storage.init();
  await storage.saveProfile(profile ?? UserProfile.defaultProfile());
  final state = AppState(
    storage: storage,
    health: health ?? StubHealthService(sessions: sessions, rawPoints: rawPoints),
    auth: auth ?? FakeAuthService(signedIn: signedIn),
    backend: backend ?? FakeBackendService(),
  );
  await state.init();
  return state;
}
