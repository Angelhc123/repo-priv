import 'package:flutter/material.dart';
import '../models/swim_session.dart';

enum SpO2Status {
  normal,
  warning, // Mild hypoxemia
  danger,  // Emergency
}

enum WaterTempStatus {
  optimal,
  safe,
  danger,
  notAvailable,
}

class EvaluationResult {
  final String title;
  final String description;
  final Color color;
  final bool hasAlert;

  EvaluationResult({
    required this.title,
    required this.description,
    required this.color,
    this.hasAlert = false,
  });
}

class ReferenceSpeed {
  final double metersPerMinute;
  final String label;

  const ReferenceSpeed({required this.metersPerMinute, required this.label});
}

/// Tiempo pasado en una zona de FC (0 a 5, ver [RulesEngine.getHeartRateZone])
/// durante una sesión, y qué porcentaje representa del tiempo total cubierto
/// por la serie de FC (no de la duración total de la sesión, si la serie
/// tiene huecos).
class ZoneTime {
  final int zone;
  final Duration duration;
  final double percentage;

  const ZoneTime({
    required this.zone,
    required this.duration,
    required this.percentage,
  });
}

/// Comparación simple entre el pico de FC de la sesión y el promedio de los
/// últimos [window] de la serie — una aproximación de "qué tan rápido bajó
/// el pulso al terminar", no una prueba de recuperación controlada.
class HrRecoveryResult {
  final int peakBpm;
  final int finalAvgBpm;
  final int dropBpm;

  const HrRecoveryResult({
    required this.peakBpm,
    required this.finalAvgBpm,
    required this.dropBpm,
  });
}

class RulesEngine {
  /// Calculates theoretical max heart rate: 220 - age
  static int getMaxHeartRate(int age) {
    return 220 - age;
  }

  /// Reference swim speed (in meters per minute) for each declared level.
  /// Single source of truth for the pace ranges also described in
  /// [evaluatePaceVsLevel] — used both for the speed/pace chart's reference
  /// line and for [computeEfficiencyScore].
  static ReferenceSpeed referenceSpeedMetersPerMinute(String level) {
    switch (level.toLowerCase()) {
      case 'intermediate':
        return const ReferenceSpeed(metersPerMinute: 48.0, label: "Intermedio");
      case 'advanced':
        return const ReferenceSpeed(metersPerMinute: 68.0, label: "Avanzado");
      case 'competitive':
        return const ReferenceSpeed(metersPerMinute: 85.0, label: "Competitivo");
      case 'beginner':
      default:
        return const ReferenceSpeed(metersPerMinute: 40.0, label: "Principiante");
    }
  }

  /// Índice de eficiencia propio de CoSwim (no un estándar oficial como
  /// SWOLF — no hay conteo de brazadas disponible desde Health Connect).
  /// Compara el ritmo real contra el ritmo de referencia del nivel del
  /// usuario, ponderado por cuánta frecuencia cardíaca relativa se usó para
  /// lograrlo. 100 = nadando al ritmo de referencia de su nivel a ~75% de su
  /// FC máxima teórica (punto medio de la zona 3, ver [getHeartRateZone]).
  /// Devuelve null si falta algún dato de entrada.
  static int? computeEfficiencyScore({
    required double paceSecondsPer100m,
    required double? avgHeartRate,
    required int age,
    required String level,
  }) {
    if (paceSecondsPer100m <= 0 || avgHeartRate == null || avgHeartRate <= 0) {
      return null;
    }
    final maxHR = getMaxHeartRate(age);
    if (maxHR <= 0) return null;

    const targetHRPercent = 0.75;
    final refSpeed = referenceSpeedMetersPerMinute(level).metersPerMinute;
    final refPaceSecondsPer100m = 6000.0 / refSpeed;
    final actualHRPercent = avgHeartRate / maxHR;

    final paceRatio = refPaceSecondsPer100m / paceSecondsPer100m;
    final effortRatio = targetHRPercent / actualHRPercent;

    return (paceRatio * effortRatio * 100).round();
  }

  /// Evaluates the efficiency score and returns status, message, and color.
  static EvaluationResult evaluateEfficiencyScore(int? score) {
    if (score == null) {
      return EvaluationResult(
        title: "Sin datos",
        description: "Falta ritmo o frecuencia cardíaca para calcular el índice.",
        color: Colors.grey,
      );
    }

    if (score >= 120) {
      return EvaluationResult(
        title: "Excelente",
        description: "Índice $score: nadando más rápido que tu referencia con un esfuerzo relativo bajo.",
        color: Colors.green,
      );
    } else if (score >= 90) {
      return EvaluationResult(
        title: "Estable en tu nivel",
        description: "Índice $score: rendimiento acorde a tu nivel declarado.",
        color: Colors.amber,
      );
    } else {
      return EvaluationResult(
        title: "Por debajo de tu referencia",
        description: "Índice $score: ritmo más lento o esfuerzo relativo más alto de lo esperado para tu nivel.",
        color: Colors.orange,
      );
    }
  }

  /// Evaluates which heart rate zone a given BPM falls into based on age.
  /// Returns a zone number from 1 to 5, or 0 if it's below Zone 1 (rest/low intensity).
  static int getHeartRateZone(int bpm, int age) {
    final maxHR = getMaxHeartRate(age);
    if (maxHR <= 0) return 0;
    final percentage = bpm / maxHR;

    if (percentage >= 0.90) return 5;
    if (percentage >= 0.80) return 4;
    if (percentage >= 0.70) return 3;
    if (percentage >= 0.60) return 2;
    if (percentage >= 0.50) return 1;
    return 0;
  }

  /// Returns user-friendly name of the HR zone
  static String getZoneName(int zone) {
    switch (zone) {
      case 1:
        return "Recuperación / Calentamiento";
      case 2:
        return "Resistencia básica (Aeróbico)";
      case 3:
        return "Aeróbico moderado";
      case 4:
        return "Umbral anaeróbico";
      case 5:
        return "Máximo esfuerzo";
      default:
        return "Reposo / Muy baja intensidad";
    }
  }

  /// Returns user-friendly description of the HR zone
  static String getZoneDescription(int zone) {
    switch (zone) {
      case 1:
        return "Regeneración activa. Ideal para calentar o recuperarse.";
      case 2:
        return "Desarrollo de capacidad aeróbica y resistencia general.";
      case 3:
        return "Mejora cardiovascular. Zona aeróbica segura para entrenamiento regular.";
      case 4:
        return "Desarrollo de tolerancia al lactato. Solo para entrenados.";
      case 5:
        return "Uso muy limitado. ¡Zona de esfuerzo máximo sostenido!";
      default:
        return "Intensidad baja adecuada para el descanso.";
    }
  }

  /// Returns color associated with the HR zone
  static Color getZoneColor(int zone) {
    switch (zone) {
      case 1:
        return Colors.green.shade400;
      case 2:
        return Colors.lightGreen;
      case 3:
        return Colors.amber;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.red;
      default:
        return Colors.blueGrey.shade300;
    }
  }

  /// Distribución de tiempo por zona de FC durante la sesión, integrando la
  /// serie punto a punto (cada intervalo entre dos muestras se asigna a la
  /// zona de su FC promedio). Es lo único "estilo rendimiento" que se puede
  /// calcular con los datos que Mi Fitness sí exporta a Health Connect para
  /// este reloj (ver nota en health_service.dart / memoria del proyecto:
  /// velocidad, SWOLF, VO2max, etc. no se exportan). Devuelve [] si no hay
  /// al menos 2 muestras de FC.
  static List<ZoneTime> computeHrZoneDistribution(
    SwimSession session, {
    required int age,
  }) {
    final series = session.heartRateSeries;
    if (series.length < 2) return [];

    final totalsMs = <int, int>{};
    for (int i = 1; i < series.length; i++) {
      final prev = series[i - 1];
      final curr = series[i];
      final dtMs = curr.time.difference(prev.time).inMilliseconds;
      if (dtMs <= 0) continue;
      final avgBpm = ((prev.bpm + curr.bpm) / 2).round();
      final zone = getHeartRateZone(avgBpm, age);
      totalsMs[zone] = (totalsMs[zone] ?? 0) + dtMs;
    }

    final totalMs = totalsMs.values.fold<int>(0, (a, b) => a + b);
    if (totalMs <= 0) return [];

    final result = <ZoneTime>[];
    for (int zone = 0; zone <= 5; zone++) {
      final ms = totalsMs[zone] ?? 0;
      if (ms <= 0) continue;
      result.add(ZoneTime(
        zone: zone,
        duration: Duration(milliseconds: ms),
        percentage: ms / totalMs * 100,
      ));
    }
    return result;
  }

  /// Carga de entrenamiento estilo TRIMP de Edwards: minutos en cada zona
  /// ponderados por el número de zona (1 a 5; la zona 0 "reposo" no suma
  /// carga). No es el TRIMP de Banister (ese necesita FC de reposo, que
  /// Health Connect nunca trae para este reloj — ver dump de diagnóstico).
  /// Devuelve null si no hay zonas calculadas.
  static double? computeTrainingLoad(List<ZoneTime> zones) {
    if (zones.isEmpty) return null;
    double load = 0;
    for (final z in zones) {
      load += (z.duration.inSeconds / 60.0) * z.zone;
    }
    return load;
  }

  /// Clasifica la carga de entrenamiento calculada por [computeTrainingLoad].
  /// Umbrales propios de CoSwim (no un estándar clínico), pensados para una
  /// sesión de nado de entre 30 y 120 minutos.
  static EvaluationResult evaluateTrainingLoad(double? load) {
    if (load == null) {
      return EvaluationResult(
        title: "Sin datos",
        description: "Falta serie de FC para calcular la carga de esta sesión.",
        color: Colors.grey,
      );
    }
    if (load < 30) {
      return EvaluationResult(
        title: "Carga suave",
        description: "Carga ${load.round()}: sesión de intensidad baja, ideal para recuperación.",
        color: Colors.green,
      );
    } else if (load < 60) {
      return EvaluationResult(
        title: "Carga moderada",
        description: "Carga ${load.round()}: entrenamiento aeróbico típico.",
        color: Colors.lightGreen,
      );
    } else if (load < 100) {
      return EvaluationResult(
        title: "Carga alta",
        description: "Carga ${load.round()}: sesión exigente, cuidá la recuperación posterior.",
        color: Colors.orange,
      );
    } else {
      return EvaluationResult(
        title: "Carga muy alta",
        description: "Carga ${load.round()}: esfuerzo elevado y/o sesión larga en zonas altas.",
        color: Colors.red,
      );
    }
  }

  /// Compara el pico de FC contra el promedio de los últimos [window] de la
  /// serie, como aproximación de qué tanto bajó el pulso al terminar.
  static HrRecoveryResult? computeHrRecovery(
    SwimSession session, {
    Duration window = const Duration(minutes: 2),
  }) {
    final series = session.heartRateSeries;
    if (series.length < 2) return null;

    final peak = series.map((p) => p.bpm).reduce((a, b) => a > b ? a : b);
    final cutoff = series.last.time.subtract(window);
    final finalPoints = series.where((p) => !p.time.isBefore(cutoff)).toList();
    if (finalPoints.isEmpty) return null;

    final finalAvg =
        (finalPoints.map((p) => p.bpm).reduce((a, b) => a + b) / finalPoints.length)
            .round();
    return HrRecoveryResult(
      peakBpm: peak,
      finalAvgBpm: finalAvg,
      dropBpm: peak - finalAvg,
    );
  }

  /// Calorías gastadas por cada 100m nadados — comparable entre sesiones de
  /// distinta distancia total. Null si falta distancia o calorías.
  static double? caloriesPer100m(SwimSession session) {
    if (session.distance <= 0 || session.calories <= 0) return null;
    return session.calories / (session.distance / 100.0);
  }

  /// FC promedio de la sesión como % de la FC máxima teórica (220 - edad).
  static double? averageIntensityPercent(double? avgHeartRate, int age) {
    if (avgHeartRate == null || avgHeartRate <= 0) return null;
    final maxHR = getMaxHeartRate(age);
    if (maxHR <= 0) return null;
    return avgHeartRate / maxHR * 100;
  }

  /// Checks if heart rate exceeds 90% of max HR for more than 60 seconds.
  /// Assuming HR readings are taken at a frequency of 1 Hz (1 reading per second),
  /// meaning we need 60 consecutive readings above the threshold.
  /// If readings are at a different frequency, we can specify [readingIntervalSeconds].
  static bool checkMaxHeartRateAlert(List<int> bpms, int age, {int readingIntervalSeconds = 1}) {
    if (bpms.isEmpty) return false;
    final maxHR = getMaxHeartRate(age);
    final threshold = maxHR * 0.90;
    final requiredConsecutiveReadings = (60 / readingIntervalSeconds).ceil();

    int consecutiveCount = 0;
    for (final bpm in bpms) {
      if (bpm > threshold) {
        consecutiveCount++;
        if (consecutiveCount >= requiredConsecutiveReadings) {
          return true;
        }
      } else {
        consecutiveCount = 0;
      }
    }
    return false;
  }

  /// Evaluates SpO2 level and returns status, message, and color
  static EvaluationResult evaluateSpO2(double? spo2) {
    if (spo2 == null) {
      return EvaluationResult(
        title: "Sin datos",
        description: "Métrica de SpO2 no disponible en esta sesión.",
        color: Colors.grey,
      );
    }

    if (spo2 < 90) {
      return EvaluationResult(
        title: "Urgente: SpO2 Crítico",
        description: "SpO2 bajo ($spo2%) — consulta médica recomendada de inmediato.",
        color: Colors.red,
        hasAlert: true,
      );
    } else if (spo2 >= 91 && spo2 <= 94) {
      return EvaluationResult(
        title: "Aviso: SpO2 Levemente Bajo",
        description: "SpO2 de $spo2% indica hipoxemia leve. Monitorea e infórmate.",
        color: Colors.amber,
        hasAlert: true,
      );
    } else {
      return EvaluationResult(
        title: "Normal",
        description: "SpO2 de $spo2% dentro de rango normal (95% - 100%).",
        color: Colors.green,
      );
    }
  }

  /// Evaluates Water Temperature against FINA/World Aquatics & safety guidelines
  static EvaluationResult evaluateWaterTemperature(double? temp) {
    if (temp == null) {
      return EvaluationResult(
        title: "Dato no disponible",
        description: "Temperatura del agua no disponible en este dispositivo.",
        color: Colors.grey,
      );
    }

    if (temp < 18 || temp > 31) {
      return EvaluationResult(
        title: "Temperatura fuera de rango",
        description: "El agua a $temp°C está fuera del rango seguro de referencia (18°C - 31°C).",
        color: Colors.red,
        hasAlert: true,
      );
    } else if (temp >= 25 && temp <= 28) {
      return EvaluationResult(
        title: "Temperatura Óptima",
        description: "Temperatura de $temp°C es ideal para competición estándar (FINA).",
        color: Colors.green,
      );
    } else {
      return EvaluationResult(
        title: "Temperatura Aceptable",
        description: "Temperatura de $temp°C es segura para natación recreativa o entrenamiento.",
        color: Colors.blue,
      );
    }
  }

  /// Compares user's actual pace (in seconds per 100m) with the reference range of their declared level.
  /// Returns a user-friendly comparison message.
  static String evaluatePaceVsLevel(double paceSecondsPer100m, String level) {
    if (paceSecondsPer100m <= 0) return "Sin ritmo registrado";
    
    // Limits in seconds per 100m
    // Beginner: > 2:30 (150s)
    // Intermediate: 1:45 (105s) to 2:30 (150s)
    // Advanced: 1:15 (75s) to 1:45 (105s)
    // Competitive: < 1:15 (75s)
    
    final int pace = paceSecondsPer100m.round();
    final int min = pace ~/ 60;
    final int sec = pace % 60;
    final String formattedPace = "$min:${sec.toString().padLeft(2, '0')}/100m";

    switch (level.toLowerCase()) {
      case 'beginner':
        if (pace > 150) {
          return "Ritmo ($formattedPace): Normal para principiante (esperado > 2:30). ¡Sigue así!";
        } else {
          return "Ritmo ($formattedPace): ¡Excelente! Estás nadando más rápido de lo esperado para un principiante.";
        }
      case 'intermediate':
        if (pace > 150) {
          return "Ritmo ($formattedPace): Un poco lento para nivel intermedio (esperado 1:45 - 2:30).";
        } else if (pace >= 105 && pace <= 150) {
          return "Ritmo ($formattedPace): En el rango óptimo para nivel intermedio.";
        } else {
          return "Ritmo ($formattedPace): ¡Muy rápido! Estás rindiendo a nivel avanzado.";
        }
      case 'advanced':
        if (pace > 105) {
          return "Ritmo ($formattedPace): Más lento del rango avanzado (esperado 1:15 - 1:45).";
        } else if (pace >= 75 && pace <= 105) {
          return "Ritmo ($formattedPace): En el rango óptimo de nivel avanzado.";
        } else {
          return "Ritmo ($formattedPace): ¡Espectacular! Estás nadando a nivel competitivo.";
        }
      case 'competitive':
        if (pace >= 75) {
          return "Ritmo ($formattedPace): Por debajo del nivel competitivo estándar (esperado < 1:15).";
        } else {
          return "Ritmo ($formattedPace): Ritmo competitivo de élite ($formattedPace).";
        }
      default:
        return "Ritmo registrado: $formattedPace.";
    }
  }
}
