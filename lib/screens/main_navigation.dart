import 'package:flutter/material.dart';
import '../services/app_state.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'charts_screen.dart';

/// 3 pestañas: Entrenamientos (historial + detalle), Progreso (tendencias) y
/// Datos (el dashboard de depuración original).
///
/// Los 3 hijos se montan una sola vez dentro de un IndexedStack y solo se
/// cambia cuál es visible — NUNCA reconstruir condicionalmente qué widget se
/// muestra según appState.isLoading. Ese patrón ya causó un bucle infinito
/// una vez: DashboardScreen.initState() pide permisos y llama a
/// appState.refreshData(), que pone isLoading en true mientras trabaja; si
/// esta pantalla reacciona a eso reemplazando el subárbol, Flutter destruye
/// el DashboardScreen montado, y al volver isLoading a false crea una
/// instancia NUEVA cuyo initState() vuelve a pedir permisos y refrescar —
/// poniendo isLoading en true de nuevo. IndexedStack evita esto: los 3 hijos
/// existen siempre, cambiar de pestaña o que cambie isLoading nunca los
/// destruye ni recrea.
class MainNavigation extends StatefulWidget {
  final AppState appState;

  const MainNavigation({super.key, required this.appState});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HistoryScreen(appState: widget.appState),
          ChartsScreen(appState: widget.appState),
          DashboardScreen(appState: widget.appState),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0D253F),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.pool), label: "Entrenamientos"),
          NavigationDestination(icon: Icon(Icons.trending_up), label: "Progreso"),
          NavigationDestination(icon: Icon(Icons.storage), label: "Datos"),
        ],
      ),
    );
  }
}
