import 'package:flutter/material.dart';
import '../services/app_state.dart';
import 'dashboard_screen.dart';

/// Solo queda la pestaña "Datos". "En Vivo" (realtime_monitor_screen.dart)
/// se sacó de la navegación: Health Connect no expone un entrenamiento "en
/// curso" (Mi Fitness recién escribe el ExerciseSessionRecord completo al
/// terminar y sincronizar), así que esa pantalla terminaba sumando
/// pulsaciones/calorías/distancia sueltas de las últimas 12h y mostrándolas
/// como si fueran del "entrenamiento activo" aunque no hubiera ninguno en
/// curso. El archivo queda sin usar, igual que history/charts/profile.
class MainNavigation extends StatelessWidget {
  final AppState appState;

  const MainNavigation({super.key, required this.appState});

  // NO envolver esto en un ListenableBuilder que intercambie DashboardScreen
  // por otro widget cuando appState.isLoading es true. main() ya espera a
  // appState.init() antes de runApp(), así que isLoading siempre es false en
  // el primer frame — ese swap nunca servía para una carga inicial. Lo único
  // que causaba era esto: DashboardScreen.initState() pide permisos y llama
  // a appState.refreshData(), que pone isLoading en true mientras trabaja;
  // si esta pantalla reacciona a eso reemplazando el subárbol, Flutter
  // destruye el DashboardScreen montado, y al volver isLoading a false crea
  // una instancia NUEVA cuyo initState() vuelve a pedir permisos y refrescar
  // — poniendo isLoading en true de nuevo. Bucle infinito parpadeando entre
  // pantallas de carga que nunca llega a mostrar nada.
  // DashboardScreen ya maneja su propio spinner de carga (_isFetchingRaw)
  // sin necesidad de destruirse a sí mismo.
  @override
  Widget build(BuildContext context) {
    return DashboardScreen(appState: appState);
  }
}
