import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/swim_session.dart';
import '../utils/rules_engine.dart';
import '../utils/splits_calculator.dart';
import '../widgets/charts/heart_rate_series_chart.dart';

class SessionDetailScreen extends StatelessWidget {
  final SwimSession session;
  final AppState appState;

  const SessionDetailScreen({super.key, required this.session, required this.appState});

  @override
  Widget build(BuildContext context) {
    final age = appState.profile.age;
    final level = appState.profile.level;
    final splits = computeSplits(session, age: age, level: level);
    final score = RulesEngine.computeEfficiencyScore(
      paceSecondsPer100m: session.paceSecondsPer100m,
      avgHeartRate: session.averageHeartRate,
      age: age,
      level: level,
    );
    final scoreEval = RulesEngine.evaluateEfficiencyScore(score);
    final zones = RulesEngine.computeHrZoneDistribution(session, age: age);
    final load = RulesEngine.computeTrainingLoad(zones);
    final loadEval = RulesEngine.evaluateTrainingLoad(load);
    final recovery = RulesEngine.computeHrRecovery(session);

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D253F),
        elevation: 0,
        title: Text(
          DateFormat('EEEE d MMMM, HH:mm', 'es').format(session.startTime),
          style: const TextStyle(color: Color(0xFF64FFDA), fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsGrid(age),
            const SizedBox(height: 16),
            _buildEfficiencyCard(score, scoreEval),
            if (zones.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTrainingLoadCard(load, loadEval, zones),
            ],
            if (recovery != null) ...[
              const SizedBox(height: 16),
              _buildRecoveryCard(recovery),
            ],
            const SizedBox(height: 20),
            _buildCard(
              title: "Frecuencia Cardíaca",
              subtitle: "Pulsaciones durante el entrenamiento",
              child: HeartRateSeriesChart(session: session, age: age),
            ),
            if (session.heartRateSeries.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildCard(
                title: "Distribución de FC",
                subtitle: "Cuántas muestras cayeron en cada rango de pulsaciones",
                child: _buildHrHistogram(),
              ),
            ],
            if (session.calorieSeries.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildCard(
                title: "Calorías en el Tiempo",
                subtitle: "Gasto calórico por intervalo registrado",
                child: _buildCalorieChart(),
              ),
            ],
            if (session.stepSeries.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildCard(
                title: "Actividad (Pasos)",
                subtitle: "Conteo de pasos por intervalo — en natación suele venir del movimiento de brazada, no es una métrica oficial",
                child: _buildStepChart(),
              ),
            ],
            const SizedBox(height: 20),
            _buildCard(
              title: "Saturación de Oxígeno",
              subtitle: "SpO2 durante el entrenamiento",
              footerNote: session.spo2Series.isEmpty
                  ? "Este reloj no registró SpO2 continua durante esta sesión."
                  : null,
              child: _buildSpO2Chart(),
            ),
            const SizedBox(height: 20),
            _buildCard(
              title: "Ritmo por Tramo (100m)",
              subtitle: "Calculado a partir de la velocidad registrada",
              footerNote: splits.isEmpty
                  ? null
                  : "Splits estimados a partir de la serie de velocidad del reloj; no son mediciones oficiales por largo de piscina.",
              child: splits.isEmpty
                  ? const Center(
                      child: Text(
                        "Sin datos de velocidad suficientes para calcular splits de 100m en este entrenamiento.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    )
                  : _buildSplitsChart(splits),
            ),
            if (splits.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSplitsTable(splits),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(int age) {
    final calPer100 = RulesEngine.caloriesPer100m(session);
    final intensity = RulesEngine.averageIntensityPercent(session.averageHeartRate, age);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        children: [
          _buildStat("Distancia", "${session.distance.toInt()} m"),
          _buildStat("Duración", "${session.duration.inMinutes} min"),
          _buildStat("Ritmo", session.paceString),
          _buildStat(
            "FC Prom.",
            session.averageHeartRate != null ? "${session.averageHeartRate!.round()} bpm" : "N/A",
          ),
          _buildStat(
            "FC Máx.",
            session.maxHeartRate != null ? "${session.maxHeartRate!.round()} bpm" : "N/A",
          ),
          _buildStat("Calorías", "${session.calories.round()} kcal"),
          _buildStat(
            "SpO2 Prom.",
            session.spo2 != null ? "${session.spo2!.round()}%" : "N/A",
          ),
          _buildStat(
            "Cal/100m",
            calPer100 != null ? calPer100.toStringAsFixed(1) : "N/A",
          ),
          _buildStat(
            "Intensidad",
            intensity != null ? "${intensity.round()}% FCmáx" : "N/A",
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEfficiencyCard(int? score, EvaluationResult eval) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: eval.color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text(
            score?.toString() ?? "--",
            style: TextStyle(color: eval.color, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Índice de eficiencia · ${eval.title}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(eval.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingLoadCard(
      double? load, EvaluationResult eval, List<ZoneTime> zones) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: eval.color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                load != null ? load.round().toString() : "--",
                style: TextStyle(color: eval.color, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Carga de entrenamiento · ${eval.title}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(eval.description, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildZoneBar(zones),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              for (final z in zones)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, color: RulesEngine.getZoneColor(z.zone)),
                    const SizedBox(width: 4),
                    Text(
                      "Z${z.zone} ${z.percentage.round()}%",
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneBar(List<ZoneTime> zones) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            for (final z in zones)
              Expanded(
                flex: (z.percentage * 10).round().clamp(1, 1000),
                child: Container(color: RulesEngine.getZoneColor(z.zone)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecoveryCard(HrRecoveryResult recovery) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Recuperación de FC",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  "Pico ${recovery.peakBpm} bpm → últimos 2 min: ${recovery.finalAvgBpm} bpm",
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            recovery.dropBpm > 0 ? "-${recovery.dropBpm}" : "${recovery.dropBpm}",
            style: TextStyle(
              color: recovery.dropBpm > 0 ? const Color(0xFF64FFDA) : Colors.orange,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required Widget child,
    String? footerNote,
  }) {
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
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(height: 20),
          SizedBox(height: 200, child: child),
          if (footerNote != null) ...[
            const SizedBox(height: 12),
            Text(footerNote, style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }

  Widget _buildHrHistogram() {
    const bucketSize = 10;
    final counts = <int, int>{};
    for (final p in session.heartRateSeries) {
      final bucket = (p.bpm / bucketSize).floor() * bucketSize;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    final buckets = counts.keys.toList()..sort();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < buckets.length) {
                  return Text("${buckets[index]}",
                      style: const TextStyle(color: Colors.white54, fontSize: 9));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) =>
                  Text("${value.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 9)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < buckets.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: counts[buckets[i]]!.toDouble(),
                color: RulesEngine.getZoneColor(RulesEngine.getHeartRateZone(buckets[i], appState.profile.age)),
                width: 14,
                borderRadius: BorderRadius.circular(3),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildCalorieChart() {
    final points = session.calorieSeries;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < points.length) {
                  final minutes = points[index].startTime.difference(session.startTime).inMinutes;
                  return Text("${minutes}m", style: const TextStyle(color: Colors.white54, fontSize: 9));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) =>
                  Text("${value.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 9)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: points[i].kcal,
                color: Colors.orangeAccent,
                width: 14,
                borderRadius: BorderRadius.circular(3),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildStepChart() {
    final points = session.stepSeries;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < points.length) {
                  final minutes = points[index].startTime.difference(session.startTime).inMinutes;
                  return Text("${minutes}m", style: const TextStyle(color: Colors.white54, fontSize: 9));
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) =>
                  Text("${value.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 9)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: points[i].count.toDouble(),
                color: Colors.lightBlueAccent,
                width: 14,
                borderRadius: BorderRadius.circular(3),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _buildSpO2Chart() {
    if (session.spo2Series.isEmpty) {
      return const Center(child: Text("Sin serie de SpO2 registrada", style: TextStyle(color: Colors.white38)));
    }

    final startTime = session.startTime;
    final spots = session.spo2Series
        .map((p) => FlSpot(p.time.difference(startTime).inSeconds / 60.0, p.percentage))
        .toList();

    return LineChart(
      LineChartData(
        minY: 80,
        maxY: 102,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) => Text(
                "${value.toStringAsFixed(1)}m",
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                "${value.toInt()}%",
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: const Color(0xFF64FFDA),
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3,
                color: spot.y < 90 ? Colors.red : (spot.y <= 94 ? Colors.amber : const Color(0xFF64FFDA)),
                strokeWidth: 1,
                strokeColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitsChart(List<SplitResult> splits) {
    final maxPace = splits.map((s) => s.paceSecondsPer100m).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxPace * 1.15,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < splits.length) {
                  return Text(
                    "${splits[index].markMeters.toInt()}m",
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                "${value.toInt()}s",
                style: const TextStyle(color: Colors.white54, fontSize: 9),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (int i = 0; i < splits.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: splits[i].paceSecondsPer100m,
                color: _colorForScore(splits[i].efficiencyScore),
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ]),
        ],
      ),
    );
  }

  Color _colorForScore(int? score) {
    if (score == null) return Colors.white38;
    if (score >= 120) return Colors.green;
    if (score >= 90) return Colors.amber;
    return Colors.orange;
  }

  Widget _buildSplitsTable(List<SplitResult> splits) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D253F),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < splits.length; i++) ...[
            if (i > 0) const Divider(color: Colors.white10, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${splits[i].markMeters.toInt()}m",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(_formatPace(splits[i].paceSecondsPer100m),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    splits[i].avgHeartRate != null ? "${splits[i].avgHeartRate!.round()} bpm" : "-- bpm",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    "Índice ${splits[i].efficiencyScore?.toString() ?? '--'}",
                    style: TextStyle(color: _colorForScore(splits[i].efficiencyScore), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatPace(double secondsPer100m) {
    final total = secondsPer100m.round();
    return "${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}/100m";
  }
}
