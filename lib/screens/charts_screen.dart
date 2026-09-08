import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../models/swim_session.dart';
import '../utils/rules_engine.dart';

class ChartsScreen extends StatefulWidget {
  final AppState appState;

  const ChartsScreen({super.key, required this.appState});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  SwimSession? _selectedSession;

  @override
  void initState() {
    super.initState();
    if (widget.appState.sessions.isNotEmpty) {
      _selectedSession = widget.appState.sessions.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.appState.sessions;
    final age = widget.appState.profile.age;
    final userLevel = widget.appState.profile.level;

    // Handle updates to sessions list
    if (_selectedSession == null && sessions.isNotEmpty) {
      _selectedSession = sessions.first;
    } else if (_selectedSession != null && !sessions.any((s) => s.id == _selectedSession!.id)) {
      _selectedSession = sessions.isNotEmpty ? sessions.first : null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D253F),
        elevation: 0,
        title: const Text(
          "Gráficos de Progreso",
          style: TextStyle(
            color: Color(0xFF64FFDA),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: sessions.isEmpty
          ? _buildEmptyState()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Chart: Distance over time
                  _buildCard(
                    title: "Distancia Nadada por Sesión",
                    subtitle: "Progreso histórico en metros",
                    child: _buildDistanceChart(sessions),
                  ),
                  const SizedBox(height: 20),

                  // 2. Chart: Heart Rate Series for a specific session
                  _buildCard(
                    title: "Frecuencia Cardíaca Continua",
                    subtitle: "Frecuencia cardíaca y zonas de esfuerzo",
                    headerExtension: _buildSessionSelector(sessions),
                    child: _buildHeartRateSeriesChart(_selectedSession, age),
                  ),
                  const SizedBox(height: 20),

                  // 3. Chart: Calories burned per week
                  _buildCard(
                    title: "Calorías Quemadas por Semana",
                    subtitle: "Consumo calórico semanal",
                    child: _buildWeeklyCaloriesChart(sessions),
                  ),
                  const SizedBox(height: 20),

                  // 4. Chart: SpO2 levels
                  _buildCard(
                    title: "Saturación de Oxígeno (SpO2)",
                    subtitle: "Valores registrados en reposo",
                    footerNote: "Nota: Métrica medida en reposo. No es una medición continua durante el nado activo.",
                    child: _buildSpO2Chart(sessions),
                  ),
                  const SizedBox(height: 20),

                  // 5. Chart: Speed / Pace per session
                  _buildCard(
                    title: "Velocidad de Nado por Sesión",
                    subtitle: "Rendimiento promedio en metros por minuto",
                    footerNote: "La línea discontinua representa la referencia sugerida para tu nivel.",
                    child: _buildSpeedChart(sessions, userLevel),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.white24),
          SizedBox(height: 16),
          Text(
            "Cargando gráficos...",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? headerExtension,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (headerExtension != null) headerExtension,
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: 200, child: child),
          if (footerNote != null) ...[
            const SizedBox(height: 12),
            Text(
              footerNote,
              style: const TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSessionSelector(List<SwimSession> sessions) {
    return DropdownButton<String>(
      value: _selectedSession?.id,
      dropdownColor: const Color(0xFF0D253F),
      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64FFDA)),
      underline: Container(),
      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedSession = sessions.firstWhere((s) => s.id == newValue);
          });
        }
      },
      items: sessions.map<DropdownMenuItem<String>>((SwimSession s) {
        final dateStr = DateFormat('dd/MM').format(s.startTime);
        return DropdownMenuItem<String>(
          value: s.id,
          child: Text("$dateStr (${s.distance.toInt()}m)"),
        );
      }).toList(),
    );
  }

  // --- 1. Distance Chart ---
  Widget _buildDistanceChart(List<SwimSession> sessions) {
    // Show in chronological order for graphs (left to right)
    final chronological = sessions.reversed.toList();
    List<FlSpot> spots = [];
    for (int i = 0; i < chronological.length; i++) {
      spots.add(FlSpot(i.toDouble(), chronological[i].distance));
    }

    return LineChart(
      LineChartData(
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
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < chronological.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat('dd/MM').format(chronological[index].startTime),
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  "${value.toInt()}m",
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF30BCED),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF30BCED).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Heart Rate Continuous Series Chart with Background Zones ---
  Widget _buildHeartRateSeriesChart(SwimSession? session, int age) {
    if (session == null || session.heartRateSeries.isEmpty) {
      return const Center(child: Text("Sin serie de FC registrada", style: TextStyle(color: Colors.white38)));
    }

    final series = session.heartRateSeries;
    final maxHR = RulesEngine.getMaxHeartRate(age).toDouble();

    // Map series to minutes
    final startTime = session.startTime;
    List<FlSpot> spots = [];
    for (final pt in series) {
      final elapsedMinutes = pt.time.difference(startTime).inSeconds / 60.0;
      spots.add(FlSpot(elapsedMinutes, pt.bpm.toDouble()));
    }

    // HR Zones percentages
    final zone1Min = maxHR * 0.50;
    final zone2Min = maxHR * 0.60;
    final zone3Min = maxHR * 0.70;
    final zone4Min = maxHR * 0.80;
    final zone5Min = maxHR * 0.90;

    return LineChart(
      LineChartData(
        minY: 50,
        maxY: (maxHR + 10).clamp(150, 230),
        gridData: const FlGridData(show: false),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(y1: zone1Min, y2: zone2Min, color: Colors.green.shade400.withOpacity(0.08)),
            HorizontalRangeAnnotation(y1: zone2Min, y2: zone3Min, color: Colors.lightGreen.withOpacity(0.08)),
            HorizontalRangeAnnotation(y1: zone3Min, y2: zone4Min, color: Colors.amber.withOpacity(0.08)),
            HorizontalRangeAnnotation(y1: zone4Min, y2: zone5Min, color: Colors.orange.withOpacity(0.08)),
            HorizontalRangeAnnotation(y1: zone5Min, y2: maxHR + 20, color: Colors.red.withOpacity(0.1)),
          ],
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "${value.toStringAsFixed(1)}m",
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() % 20 == 0) {
                  return Text(
                    "${value.toInt()}",
                    style: const TextStyle(color: Colors.white54, fontSize: 9),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.redAccent,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  // --- 3. Weekly Calories Chart ---
  Widget _buildWeeklyCaloriesChart(List<SwimSession> sessions) {
    // Simple grouping: since we have mock data over ~12 days, we group into 3 bins:
    // Bin 0 (0-7 days ago), Bin 1 (8-14 days ago), Bin 2 (15+ days ago)
    final now = DateTime.now();
    double week1 = 0; // Current week (0-6 days)
    double week2 = 0; // Last week (7-13 days)
    double week3 = 0; // Two weeks ago (14+ days)

    for (final s in sessions) {
      final difference = now.difference(s.startTime).inDays;
      if (difference < 7) {
        week1 += s.calories;
      } else if (difference < 14) {
        week2 += s.calories;
      } else {
        week3 += s.calories;
      }
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (week1 > week2 ? (week1 > week3 ? week1 : week3) : (week2 > week3 ? week2 : week3)) + 200,
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                switch (value.toInt()) {
                  case 0:
                    return const Text("Esta Sem.", style: TextStyle(color: Colors.white54, fontSize: 10));
                  case 1:
                    return const Text("Sem. Pas.", style: TextStyle(color: Colors.white54, fontSize: 10));
                  case 2:
                    return const Text("Sem. Ant.", style: TextStyle(color: Colors.white54, fontSize: 10));
                  default:
                    return const Text("");
                }
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  "${value.toInt()} kcal",
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: week1, color: Colors.orange, width: 20, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: week2, color: Colors.amber, width: 20, borderRadius: BorderRadius.circular(4))]),
          BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: week3, color: Colors.yellow, width: 20, borderRadius: BorderRadius.circular(4))]),
        ],
      ),
    );
  }

  // --- 4. SpO2 Chart ---
  Widget _buildSpO2Chart(List<SwimSession> sessions) {
    final chronological = sessions.reversed.toList();
    List<FlSpot> spots = [];
    for (int i = 0; i < chronological.length; i++) {
      if (chronological[i].spo2 != null) {
        spots.add(FlSpot(i.toDouble(), chronological[i].spo2!));
      }
    }

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
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < chronological.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat('dd/MM').format(chronological[index].startTime),
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  "${value.toInt()}%",
                  style: const TextStyle(color: Colors.white54, fontSize: 9),
                );
              },
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
                radius: 4,
                color: spot.y < 90
                    ? Colors.red
                    : (spot.y <= 94 ? Colors.amber : const Color(0xFF64FFDA)),
                strokeWidth: 1,
                strokeColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Speed / Pace Chart with Reference Level Line ---
  Widget _buildSpeedChart(List<SwimSession> sessions, String userLevel) {
    final chronological = sessions.reversed.toList();
    List<FlSpot> spots = [];
    for (int i = 0; i < chronological.length; i++) {
      spots.add(FlSpot(i.toDouble(), chronological[i].metersPerMinute));
    }

    // Determine reference speed in meters per minute (m/min) based on level
    // Beginner: > 2:30 min/100m -> ~40 m/min
    // Intermediate: 1:45-2:30 min/100m -> ~40-57 m/min (midpoint = 48)
    // Advanced: 1:15-1:45 min/100m -> ~57-80 m/min (midpoint = 68)
    // Competitive: < 1:15 min/100m -> ~80+ m/min (midpoint = 85)
    double refSpeed = 40.0;
    String refLabel = "Principiante (40 m/min)";
    switch (userLevel.toLowerCase()) {
      case 'beginner':
        refSpeed = 40.0;
        refLabel = "Principiante";
        break;
      case 'intermediate':
        refSpeed = 48.0;
        refLabel = "Intermedio";
        break;
      case 'advanced':
        refSpeed = 68.0;
        refLabel = "Avanzado";
        break;
      case 'competitive':
        refSpeed = 85.0;
        refLabel = "Competitivo";
        break;
    }

    return LineChart(
      LineChartData(
        minY: 10,
        maxY: 110,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (val) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: refSpeed,
              color: const Color(0xFF64FFDA).withOpacity(0.6),
              strokeWidth: 2,
              dashArray: [5, 5],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                labelResolver: (line) => "Ref: $refLabel",
                style: const TextStyle(color: Color(0xFF64FFDA), fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < chronological.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat('dd/MM').format(chronological[index].startTime),
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  "${value.toInt()} m/min",
                  style: const TextStyle(color: Colors.white54, fontSize: 8),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF30BCED),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF30BCED).withOpacity(0.05),
            ),
          ),
        ],
      ),
    );
  }
}
