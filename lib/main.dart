import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/app_state.dart';
import 'screens/main_navigation.dart';

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
      home: MainNavigation(appState: appState),
    );
  }
}
