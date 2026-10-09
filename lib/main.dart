import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/app_state.dart';
import 'screens/main_navigation.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize spanish date formatting
  await initializeDateFormatting('es', null);

  final appState = AppState();
  await appState.init();

  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  final AppState appState;

  const MyApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoSwim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0D253F),
        scaffoldBackgroundColor: const Color(0xFF0A192F),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64FFDA),
          secondary: Color(0xFF30BCED),
          surface: Color(0xFF0D253F),
        ),
        useMaterial3: true,
      ),
      home: AuthGate(appState: appState),
    );
  }
}

/// Puerta única al arrancar: muestra LoginScreen o MainNavigation según
/// appState.isSignedIn, ya resuelto en appState.init() (awaited arriba en
/// main() antes de runApp). El cambio de pantalla solo ocurre cuando el
/// usuario inicia/cierra sesión explícitamente — no reacciona a isLoading,
/// así que no pisa la regla de IndexedStack documentada en main_navigation.dart.
class AuthGate extends StatefulWidget {
  final AppState appState;

  const AuthGate({super.key, required this.appState});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    if (!widget.appState.isSignedIn) {
      return LoginScreen(
        appState: widget.appState,
        onSignedIn: () => setState(() {}),
      );
    }
    return MainNavigation(appState: widget.appState);
  }
}
