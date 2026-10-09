import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:coswim/utils/rules_engine.dart';
import 'package:coswim/models/swim_session.dart';

SwimSession _sessionWithHr(List<(int secondsFromStart, int bpm)> points, {double distance = 2000}) {
  final start = DateTime(2026, 1, 1, 10, 0, 0);
  final series = points
      .map((p) => HeartRatePoint(time: start.add(Duration(seconds: p.$1)), bpm: p.$2))
      .toList();
  return SwimSession(
    id: 'test',
    startTime: start,
    endTime: start.add(Duration(seconds: points.last.$1)),
    distance: distance,
    calories: 300,
    heartRateSeries: series,
  );
}

void main() {
  group('RulesEngine Tests', () {
    test('Calcula la Frecuencia Cardíaca Máxima teórica correctamente', () {
      expect(RulesEngine.getMaxHeartRate(20), 200);
      expect(RulesEngine.getMaxHeartRate(35), 185);
      expect(RulesEngine.getMaxHeartRate(50), 170);
    });

    test('Evalúa las zonas de Frecuencia Cardíaca correctamente', () {
      // Para una persona de 20 años: FC Máx = 200.
      // Zona 1: 50-60% (100 - 120)
      // Zona 2: 60-70% (120 - 140)
      // Zona 3: 70-80% (140 - 160)
      // Zona 4: 80-90% (160 - 180)
      // Zona 5: >90% (>=180)
      expect(RulesEngine.getHeartRateZone(90, 20), 0); // Reposo
      expect(RulesEngine.getHeartRateZone(110, 20), 1); // Z1
      expect(RulesEngine.getHeartRateZone(130, 20), 2); // Z2
      expect(RulesEngine.getHeartRateZone(150, 20), 3); // Z3
      expect(RulesEngine.getHeartRateZone(170, 20), 4); // Z4
      expect(RulesEngine.getHeartRateZone(190, 20), 5); // Z5
    });

    test('Alerta de Frecuencia Cardíaca Máxima sostenida por > 60 segundos', () {
      // Edad: 20 -> FC Máx: 200, 90%: 180.
      // Lecturas cada 1 segundo (readingIntervalSeconds = 1)
      
      // Caso 1: Menos de 60 segundos sobre el límite (50 segs)
      final List<int> shortHighHR = List.filled(50, 185) + List.filled(20, 150);
      expect(
        RulesEngine.checkMaxHeartRateAlert(shortHighHR, 20, readingIntervalSeconds: 1),
        false,
      );

      // Caso 2: Exactamente 60 segundos sobre el límite
      final List<int> exact60HR = List.filled(60, 181);
      expect(
        RulesEngine.checkMaxHeartRateAlert(exact60HR, 20, readingIntervalSeconds: 1),
        true,
      );

      // Caso 3: Interrumpido (se interrumpe el esfuerzo sostenido)
      final List<int> interruptedHR = List.filled(30, 185) + [175] + List.filled(40, 185);
      expect(
        RulesEngine.checkMaxHeartRateAlert(interruptedHR, 20, readingIntervalSeconds: 1),
        false,
      );

      // Caso 4: Más de 60 segundos (70 segs)
      final List<int> longHighHR = List.filled(70, 190);
      expect(
        RulesEngine.checkMaxHeartRateAlert(longHighHR, 20, readingIntervalSeconds: 1),
        true,
      );
    });

    test('Evalúa saturación de oxígeno (SpO2) correctamente', () {
      // Caso 1: Normal (>= 95%)
      final resNormal = RulesEngine.evaluateSpO2(95);
      expect(resNormal.color, Colors.green);
      expect(resNormal.title, "Normal");
      expect(resNormal.hasAlert, false);

      // Caso 2: Hipoxemia leve (91% - 94%)
      final resWarning = RulesEngine.evaluateSpO2(92);
      expect(resWarning.color, Colors.amber);
      expect(resWarning.title, "Aviso: SpO2 Levemente Bajo");
      expect(resWarning.hasAlert, true);

      // Caso 3: Hipoxemia crítica / Emergencia (< 90%)
      final resCritical = RulesEngine.evaluateSpO2(89);
      expect(resCritical.color, Colors.red);
      expect(resCritical.title, "Urgente: SpO2 Crítico");
      expect(resCritical.hasAlert, true);

      // Caso 4: Sin datos
      final resNull = RulesEngine.evaluateSpO2(null);
      expect(resNull.color, Colors.grey);
      expect(resNull.hasAlert, false);
    });

    test('Evalúa temperatura del agua según normas de seguridad y FINA', () {
      // Caso 1: Rango óptimo competición (25°C - 28°C)
      final resOptimal = RulesEngine.evaluateWaterTemperature(26);
      expect(resOptimal.color, Colors.green);
      expect(resOptimal.title, "Temperatura Óptima");
      expect(resOptimal.hasAlert, false);

      // Caso 2: Temperatura segura recreativa/entrenamiento (18°C - 24.9°C o 28.1°C - 31°C)
      final resSafe = RulesEngine.evaluateWaterTemperature(20);
      expect(resSafe.color, Colors.blue);
      expect(resSafe.title, "Temperatura Aceptable");
      expect(resSafe.hasAlert, false);

      // Caso 3: Temperatura peligrosa / fuera de rango (< 18°C o > 31°C)
      final resCold = RulesEngine.evaluateWaterTemperature(16.5);
      expect(resCold.color, Colors.red);
      expect(resCold.hasAlert, true);

      final resHot = RulesEngine.evaluateWaterTemperature(32);
      expect(resHot.color, Colors.red);
      expect(resHot.hasAlert, true);

      // Caso 4: Sin datos
      final resNull = RulesEngine.evaluateWaterTemperature(null);
      expect(resNull.color, Colors.grey);
      expect(resNull.hasAlert, false);
    });

    test('Evalúa el ritmo comparando con el nivel autodeclarado del nadador', () {
      // Principiante (esperado > 2:30 / 100m, o sea > 150 segundos)
      final resBeginnerOk = RulesEngine.evaluatePaceVsLevel(160, 'beginner');
      expect(resBeginnerOk.contains("Normal para principiante"), true);

      final resBeginnerFast = RulesEngine.evaluatePaceVsLevel(140, 'beginner');
      expect(resBeginnerFast.contains("Excelente"), true);

      // Intermedio (esperado 1:45 - 2:30, o sea 105 - 150 segundos)
      final resIntermedRange = RulesEngine.evaluatePaceVsLevel(120, 'intermediate');
      expect(resIntermedRange.contains("rango óptimo para nivel intermedio"), true);

      final resIntermedSlow = RulesEngine.evaluatePaceVsLevel(160, 'intermediate');
      expect(resIntermedSlow.contains("Un poco lento"), true);
    });

    test('Distribución de zonas de FC cubre el 100% del tiempo con muestras', () {
      // 20 años -> FC Máx 200. 60s en zona 1 (110bpm) + 60s en zona 3 (150bpm).
      final session = _sessionWithHr([(0, 110), (60, 110), (120, 150)]);
      final zones = RulesEngine.computeHrZoneDistribution(session, age: 20);

      final totalPercentage = zones.fold<double>(0, (a, z) => a + z.percentage);
      expect(totalPercentage, closeTo(100, 0.01));
      expect(zones.any((z) => z.zone == 1), true);
    });

    test('Sin suficientes muestras de FC, no hay zonas ni carga', () {
      final session = _sessionWithHr([(0, 120)]);
      expect(RulesEngine.computeHrZoneDistribution(session, age: 20), isEmpty);
      expect(RulesEngine.computeTrainingLoad([]), null);
    });

    test('Carga de entrenamiento pondera minutos por número de zona', () {
      // 10 minutos íntegros en zona 2 (20 años, 130bpm) -> carga = 10 * 2 = 20.
      final session = _sessionWithHr([(0, 130), (600, 130)]);
      final zones = RulesEngine.computeHrZoneDistribution(session, age: 20);
      final load = RulesEngine.computeTrainingLoad(zones);
      expect(load, closeTo(20, 0.01));
      expect(RulesEngine.evaluateTrainingLoad(load).title, "Carga suave");
    });

    test('Recuperación de FC compara el pico con los últimos 2 minutos', () {
      final session = _sessionWithHr([
        (0, 120),
        (60, 170), // pico
        (550, 170), // justo antes de la ventana final de 2 min (580-700)
        (700, 130), // único punto dentro de la ventana final
      ]);
      final recovery = RulesEngine.computeHrRecovery(session);
      expect(recovery, isNotNull);
      expect(recovery!.peakBpm, 170);
      expect(recovery.finalAvgBpm, 130);
      expect(recovery.dropBpm, 40);
    });

    test('Calorías por 100m e intensidad promedio', () {
      final session = _sessionWithHr([(0, 140), (60, 140)], distance: 1000);
      expect(RulesEngine.caloriesPer100m(session), closeTo(30, 0.01)); // 300kcal / 10 tramos
      expect(RulesEngine.averageIntensityPercent(140, 20), closeTo(70, 0.01)); // 140/200
      expect(RulesEngine.averageIntensityPercent(null, 20), null);
    });
  });
}
