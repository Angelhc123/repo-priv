import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/swim_session.dart';
import '../../utils/rules_engine.dart';

/// Continuous heart-rate-over-time chart with background effort-zone bands.
/// Extracted from charts_screen.dart so the session detail screen and the
/// progress screen can share the exact same chart instead of duplicating
/// the fl_chart configuration.
class HeartRateSeriesChart extends StatelessWidget {
  final SwimSession? session;
  final int age;

  const HeartRateSeriesChart({super.key, required this.session, required this.age});

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s == null || s.heartRateSeries.isEmpty) {
      return const Center(
        child: Text("Sin serie de FC registrada", style: TextStyle(color: Colors.white38)),
      );
    }

    final series = s.heartRateSeries;
    final maxHR = RulesEngine.getMaxHeartRate(age).toDouble();

    final startTime = s.startTime;
    List<FlSpot> spots = [];
    for (final pt in series) {
      final elapsedMinutes = pt.time.difference(startTime).inSeconds / 60.0;
      spots.add(FlSpot(elapsedMinutes, pt.bpm.toDouble()));
    }

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
}
