class HeartRatePoint {
  final DateTime time;
  final int bpm;

  HeartRatePoint({required this.time, required this.bpm});

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'bpm': bpm,
      };

  factory HeartRatePoint.fromJson(Map<String, dynamic> json) => HeartRatePoint(
        time: DateTime.parse(json['time']),
        bpm: json['bpm'] as int,
      );
}

class SpeedPoint {
  final DateTime time;
  final double metersPerSecond;

  SpeedPoint({required this.time, required this.metersPerSecond});

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'metersPerSecond': metersPerSecond,
      };

  factory SpeedPoint.fromJson(Map<String, dynamic> json) => SpeedPoint(
        time: DateTime.parse(json['time']),
        metersPerSecond: (json['metersPerSecond'] as num).toDouble(),
      );
}

class LapData {
  final DateTime startTime;
  final DateTime endTime;
  final double lengthMeters;

  const LapData({
    required this.startTime,
    required this.endTime,
    required this.lengthMeters,
  });

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'lengthMeters': lengthMeters,
      };

  factory LapData.fromJson(Map<String, dynamic> json) => LapData(
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        lengthMeters: (json['lengthMeters'] as num).toDouble(),
      );
}

class SegmentData {
  final DateTime startTime;
  final DateTime endTime;
  final int segmentType;
  final int repetitions;

  const SegmentData({
    required this.startTime,
    required this.endTime,
    required this.segmentType,
    required this.repetitions,
  });

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'segmentType': segmentType,
        'repetitions': repetitions,
      };

  factory SegmentData.fromJson(Map<String, dynamic> json) => SegmentData(
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        segmentType: json['segmentType'] as int,
        repetitions: json['repetitions'] as int,
      );
}

class SwimSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final double calories;
  final double? averageHeartRate;
  final double? maxHeartRate;
  final List<HeartRatePoint> heartRateSeries;
  final double? spo2;
  final double? waterTemperature;
  final double? averageSpeed;
  final String? activityType;
  final List<LapData> laps;
  final List<SegmentData> segments;
  final List<SpeedPoint> speedSeries;

  SwimSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.calories,
    this.averageHeartRate,
    this.maxHeartRate,
    required this.heartRateSeries,
    this.spo2,
    this.waterTemperature,
    this.averageSpeed,
    this.activityType,
    this.laps = const [],
    this.segments = const [],
    this.speedSeries = const [],
  });

  Duration get duration => endTime.difference(startTime);

  double get metersPerMinute {
    if (duration.inSeconds <= 0) return 0;
    return distance / duration.inSeconds * 60;
  }

  double get paceSecondsPer100m {
    if (distance <= 0) return 0;
    return duration.inSeconds / (distance / 100.0);
  }

  String get paceString {
    if (distance <= 0) return "--:--";
    final double hundredMeters = distance / 100.0;
    if (hundredMeters <= 0) return "--:--";
    final int totalSeconds = duration.inSeconds;
    final double secondsPer100m = totalSeconds / hundredMeters;
    final int minutes = (secondsPer100m / 60).floor();
    final int seconds = (secondsPer100m % 60).round();
    return "$minutes:${seconds.toString().padLeft(2, '0')} min/100m";
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'distance': distance,
        'calories': calories,
        'averageHeartRate': averageHeartRate,
        'maxHeartRate': maxHeartRate,
        'heartRateSeries': heartRateSeries.map((e) => e.toJson()).toList(),
        'spo2': spo2,
        'waterTemperature': waterTemperature,
        'averageSpeed': averageSpeed,
        'activityType': activityType,
        'laps': laps.map((e) => e.toJson()).toList(),
        'segments': segments.map((e) => e.toJson()).toList(),
        'speedSeries': speedSeries.map((e) => e.toJson()).toList(),
      };

  factory SwimSession.fromJson(Map<String, dynamic> json) => SwimSession(
        id: json['id'] as String,
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        distance: (json['distance'] as num).toDouble(),
        calories: (json['calories'] as num).toDouble(),
        averageHeartRate: (json['averageHeartRate'] as num?)?.toDouble(),
        maxHeartRate: (json['maxHeartRate'] as num?)?.toDouble(),
        heartRateSeries: (json['heartRateSeries'] as List<dynamic>)
            .map((e) => HeartRatePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        spo2: (json['spo2'] as num?)?.toDouble(),
        waterTemperature: (json['waterTemperature'] as num?)?.toDouble(),
        averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
        activityType: json['activityType'] as String?,
        laps: (json['laps'] as List<dynamic>? ?? [])
            .map((e) => LapData.fromJson(e as Map<String, dynamic>))
            .toList(),
        segments: (json['segments'] as List<dynamic>? ?? [])
            .map((e) => SegmentData.fromJson(e as Map<String, dynamic>))
            .toList(),
        speedSeries: (json['speedSeries'] as List<dynamic>? ?? [])
            .map((e) => SpeedPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
