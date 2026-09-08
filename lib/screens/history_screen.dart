import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/swim_session.dart';
import '../utils/rules_engine.dart';

class HistoryScreen extends StatelessWidget {
  final AppState appState;

  const HistoryScreen({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    final sessions = appState.sessions;

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D253F),
        elevation: 0,
        title: const Text(
          "Historial de Sesiones",
          style: TextStyle(
            color: Color(0xFF64FFDA),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: sessions.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _buildSessionCard(context, session);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            "No hay historial registrado",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, SwimSession session) {
    final dateName = DateFormat('EEEE, d MMMM yyyy', 'es').format(session.startTime);
    final dateHour = DateFormat('HH:mm').format(session.startTime);

    // Analyze if there are alerts in this session
    final age = appState.profile.age;
    final hasHRAlert = RulesEngine.checkMaxHeartRateAlert(
      session.heartRateSeries.map((e) => e.bpm).toList(),
      age,
    );
    final spo2Eval = RulesEngine.evaluateSpO2(session.spo2);
    final hasSpO2Alert = spo2Eval.hasAlert;

    final tempEval = RulesEngine.evaluateWaterTemperature(session.waterTemperature);
    final hasTempAlert = tempEval.hasAlert;

    final hasAnyAlert = hasHRAlert || hasSpO2Alert || hasTempAlert;

    return Card(
      color: const Color(0xFF0D253F),
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date & Alert indicator Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "$dateName • $dateHour",
                  style: const TextStyle(
                    color: Color(0xFF64FFDA),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                if (hasAnyAlert)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.redAccent, width: 1),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.redAccent, size: 10),
                        SizedBox(width: 4),
                        Text(
                          "Alertas",
                          style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Distance & Duration Main Layout
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${session.distance.toInt()} m",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Distancia",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${session.duration.inMinutes} min",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      "Duración",
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 12),

            // Extra metrics row (Pace, HR Average, SpO2)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMetricItem(Icons.speed, "Ritmo", session.paceString),
                _buildMetricItem(
                  Icons.favorite,
                  "FC Prom.",
                  session.averageHeartRate != null ? "${session.averageHeartRate!.round()} BPM" : "N/A",
                ),
                _buildMetricItem(
                  Icons.bloodtype,
                  "SpO2",
                  session.spo2 != null ? "${session.spo2!.round()}%" : "N/A",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF30BCED), size: 14),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        )
      ],
    );
  }
}
