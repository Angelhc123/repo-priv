import 'package:flutter/material.dart';

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

class RulesEngine {
  /// Calculates theoretical max heart rate: 220 - age
  static int getMaxHeartRate(int age) {
    return 220 - age;
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
