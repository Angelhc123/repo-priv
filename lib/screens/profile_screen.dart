import 'package:flutter/material.dart';
import '../services/app_state.dart';
import '../models/user_profile.dart';

class ProfileScreen extends StatefulWidget {
  final AppState appState;

  const ProfileScreen({super.key, required this.appState});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _age;
  late String _level;
  late bool _useMockData;

  @override
  void initState() {
    super.initState();
    final profile = widget.appState.profile;
    _age = profile.age;
    _level = profile.level;
    _useMockData = profile.useMockData;
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final updated = UserProfile(
        age: _age,
        level: _level,
        useMockData: _useMockData,
      );

      await widget.appState.updateProfile(updated);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Perfil actualizado con éxito"),
            backgroundColor: Color(0xFF64FFDA),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D253F),
        elevation: 0,
        title: const Text(
          "Configuración de Perfil",
          style: TextStyle(
            color: Color(0xFF64FFDA),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro text
              const Text(
                "Configura tus límites y referencias",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),

              // Age section Card
              _buildSectionCard(
                title: "Edad del Usuario",
                subtitle: "Utilizado para calcular tu Frecuencia Cardíaca Máxima teórica (220 - edad) y las zonas de entrenamiento aeróbico.",
                child: TextFormField(
                  initialValue: _age.toString(),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: "Edad (Años)",
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64FFDA))),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "Ingresa tu edad";
                    final val = int.tryParse(value);
                    if (val == null || val <= 0 || val > 120) return "Ingresa una edad válida (1 - 120)";
                    return null;
                  },
                  onSaved: (value) {
                    if (value != null) {
                      _age = int.parse(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Level section Card
              _buildSectionCard(
                title: "Nivel de Natación Autodeclarado",
                subtitle: "Ajusta la línea de velocidad de referencia (metros por minuto) en tus gráficos de progreso.",
                child: DropdownButtonFormField<String>(
                  value: _level,
                  dropdownColor: const Color(0xFF0D253F),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: "Nivel de Nado",
                    labelStyle: TextStyle(color: Colors.white54),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF64FFDA))),
                  ),
                  items: const [
                    DropdownMenuItem(value: "beginner", child: Text("Principiante (> 2:30 min/100m)")),
                    DropdownMenuItem(value: "intermediate", child: Text("Intermedio (1:45 - 2:30 min/100m)")),
                    DropdownMenuItem(value: "advanced", child: Text("Avanzado (1:15 - 1:45 min/100m)")),
                    DropdownMenuItem(value: "competitive", child: Text("Competitivo (< 1:15 min/100m)")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _level = val;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Data source section Card
              _buildSectionCard(
                title: "Origen de los Datos",
                subtitle: "La aplicación opera exclusivamente en modo de datos reales conectados a la API de Google Health Connect.",
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF64FFDA), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Modo Estricto: Solo Datos Reales de Health Connect (Sin emulación/simulación)",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64FFDA),
                    foregroundColor: const Color(0xFF0A192F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Guardar Cambios",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
