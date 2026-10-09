import 'package:flutter/material.dart';
import '../services/app_state.dart';

/// Puerta de entrada: sin cuenta de Google no hay identidad de usuario en el
/// backend, así que no se puede subir ni leer historial de la base de datos.
/// Se muestra una sola vez al arrancar (ver AuthGate en main.dart), no es
/// parte del IndexedStack de main_navigation.dart.
class LoginScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onSignedIn;

  const LoginScreen({
    super.key,
    required this.appState,
    required this.onSignedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await widget.appState.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      widget.onSignedIn();
    } else {
      setState(() => _error = widget.appState.errorMessage ??
          "No se pudo iniciar sesión. Intenta de nuevo.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.pool, size: 72, color: Color(0xFF64FFDA)),
              const SizedBox(height: 16),
              const Text(
                "CoSwim",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Inicia sesión con Google para guardar tu historial\nen la nube y verlo sin depender de Health Connect.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              if (_loading)
                const CircularProgressIndicator(color: Color(0xFF64FFDA))
              else
                ElevatedButton.icon(
                  onPressed: _handleSignIn,
                  icon: const Icon(Icons.login),
                  label: const Text("Iniciar sesión con Google"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64FFDA),
                    foregroundColor: const Color(0xFF0A192F),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
