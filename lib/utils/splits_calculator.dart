import '../models/swim_session.dart';
import 'rules_engine.dart';

class SplitResult {
  final double markMeters;
  final Duration splitDuration;
  final Duration cumulativeDuration;
  final double? avgHeartRate;
  final double paceSecondsPer100m;
  final int? efficiencyScore;

  const SplitResult({
    required this.markMeters,
    required this.splitDuration,
    required this.cumulativeDuration,
    required this.avgHeartRate,
    required this.paceSecondsPer100m,
    required this.efficiencyScore,
  });
}

class _DistancePoint {
  final DateTime time;
  final double cumulativeMeters;

  const _DistancePoint(this.time, this.cumulativeMeters);
}

/// Splits a session into fixed-distance chunks (100m by default) using the
/// real speed time series recorded by the watch (`session.speedSeries`).
///
/// Health Connect has no per-length record that Mi Fitness actually writes
/// (`ExerciseLap`/`ExerciseSegment` arrive empty — see MainActivity.kt), so
/// this integrates the continuous speed series instead: cumulative distance
/// is the trapezoidal integral of speed over time, and each split's end time
/// is the point where that cumulative curve crosses a multiple of
/// [splitMeters]. If there isn't enough speed data, returns an empty list —
/// callers must show an honest empty state instead of inventing splits.
List<SplitResult> computeSplits(
  SwimSession session, {
  double splitMeters = 100,
  required int age,
  required String level,
}) {
  final series = session.speedSeries;
  if (series.length < 2) return [];

  final distancePoints = <_DistancePoint>[
    _DistancePoint(series.first.time, 0.0),
  ];
  double cumulative = 0.0;
  for (int i = 1; i < series.length; i++) {
    final prev = series[i - 1];
    final curr = series[i];
    final dtSeconds = curr.time.difference(prev.time).inMilliseconds / 1000.0;
    if (dtSeconds <= 0) continue;
    final avgSpeed = (prev.metersPerSecond + curr.metersPerSecond) / 2.0;
    cumulative += avgSpeed * dtSeconds;
    distancePoints.add(_DistancePoint(curr.time, cumulative));
  }

  final totalMeters = distancePoints.last.cumulativeMeters;
  if (totalMeters < splitMeters) return [];

  final splits = <SplitResult>[];
  DateTime previousMarkTime = distancePoints.first.time;
  double mark = splitMeters;

  int cursor = 1;
  while (mark <= totalMeters) {
    while (cursor < distancePoints.length &&
        distancePoints[cursor].cumulativeMeters < mark) {
      cursor++;
    }
    if (cursor >= distancePoints.length) break;

    final after = distancePoints[cursor];
    final before = distancePoints[cursor - 1];
    final segmentMeters = after.cumulativeMeters - before.cumulativeMeters;
    final markTime = segmentMeters <= 0
        ? after.time
        : before.time.add(
            after.time.difference(before.time) *
                ((mark - before.cumulativeMeters) / segmentMeters),
          );

    final splitDuration = markTime.difference(previousMarkTime);
    final hrInWindow = session.heartRateSeries
        .where((p) => !p.time.isBefore(previousMarkTime) && !p.time.isAfter(markTime))
        .map((p) => p.bpm.toDouble())
        .toList();
    final avgHR = hrInWindow.isEmpty
        ? null
        : hrInWindow.reduce((a, b) => a + b) / hrInWindow.length;

    final paceSecondsPer100m =
        splitDuration.inMilliseconds / 1000.0 / (splitMeters / 100.0);

    splits.add(SplitResult(
      markMeters: mark,
      splitDuration: splitDuration,
      cumulativeDuration: markTime.difference(distancePoints.first.time),
      avgHeartRate: avgHR,
      paceSecondsPer100m: paceSecondsPer100m,
      efficiencyScore: RulesEngine.computeEfficiencyScore(
        paceSecondsPer100m: paceSecondsPer100m,
        avgHeartRate: avgHR,
        age: age,
        level: level,
      ),
    ));

    previousMarkTime = markTime;
    mark += splitMeters;
  }

  return splits;
}
