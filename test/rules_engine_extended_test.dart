import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:coswim/utils/rules_engine.dart';
import 'package:coswim/models/swim_session.dart';

void main() {
  group('Zonas de FC — nombre, descripción y color para cada zona', () {
    final expectedNames = {
      0: "Reposo / Muy baja intensidad",
      1: "Recuperación / Calentamiento",
      2: "Resistencia básica (Aeróbico)",
      3: "Aeróbico moderado",
      4: "Umbral anaeróbico",
      5: "Máximo esfuerzo",
    };
    final expectedColors = {
      0: Colors.blueGrey.shade300,
      1: Colors.green.shade400,
      2: Colors.lightGreen,
      3: Colors.amber,
      4: Colors.orange,
      5: Colors.red,
    };

    for (final zone in expectedNames.keys) {
      test('getZoneName($zone)', () {
        expect(RulesEngine.getZoneName(zone), expectedNames[zone]);
      });
      test('getZoneColor($zone)', () {
        expect(RulesEngine.getZoneColor(zone), expectedColors[zone]);
      });
      test('getZoneDescription($zone) no está vacía', () {
        expect(RulesEngine.getZoneDescription(zone), isNotEmpty);
      });
    }
  });

  group('getHeartRateZone — límites exactos (20 años, FC Máx 200)', () {
    final cases = {
      99: 0, // justo debajo del 50%
      100: 1, // 50% exacto
      119: 1,
      120: 2, // 60% exacto
      139: 2,
      140: 3, // 70% exacto
      159: 3,
      160: 4, // 80% exacto
      179: 4,
      180: 5, // 90% exacto
      200: 5,
    };
    cases.forEach((bpm, zone) {
      test('$bpm bpm -> zona $zone', () {
        expect(RulesEngine.getHeartRateZone(bpm, 20), zone);
      });
    });
  });

  group('referenceSpeedMetersPerMinute', () {
    test('beginner', () {
      final r = RulesEngine.referenceSpeedMetersPerMinute('beginner');
      expect(r.metersPerMinute, 40.0);
      expect(r.label, "Principiante");
    });
    test('intermediate', () {
      final r = RulesEngine.referenceSpeedMetersPerMinute('intermediate');
      expect(r.metersPerMinute, 48.0);
    });
    test('advanced', () {
      final r = RulesEngine.referenceSpeedMetersPerMinute('advanced');
      expect(r.metersPerMinute, 68.0);
    });
    test('competitive', () {
      final r = RulesEngine.referenceSpeedMetersPerMinute('competitive');
      expect(r.metersPerMinute, 85.0);
    });
    test('nivel desconocido cae a principiante', () {
      final r = RulesEngine.referenceSpeedMetersPerMinute('no-existe');
      expect(r.metersPerMinute, 40.0);
    });
  });

  group('evaluatePaceVsLevel — ramas restantes', () {
    test('advanced, más lento que el rango', () {
      expect(RulesEngine.evaluatePaceVsLevel(120, 'advanced').contains("Más lento del rango avanzado"), true);
    });
    test('advanced, en rango óptimo', () {
      expect(RulesEngine.evaluatePaceVsLevel(90, 'advanced').contains("rango óptimo de nivel avanzado"), true);
    });
    test('advanced, más rápido (nivel competitivo)', () {
      expect(RulesEngine.evaluatePaceVsLevel(70, 'advanced').contains("Espectacular"), true);
    });
    test('competitive, por debajo del estándar', () {
      expect(RulesEngine.evaluatePaceVsLevel(80, 'competitive').contains("Por debajo del nivel competitivo"), true);
    });
    test('competitive, ritmo de élite', () {
      expect(RulesEngine.evaluatePaceVsLevel(70, 'competitive').contains("élite"), true);
    });
    test('nivel desconocido devuelve el ritmo formateado sin clasificar', () {
      expect(RulesEngine.evaluatePaceVsLevel(90, 'no-existe').contains("Ritmo registrado"), true);
    });
    test('ritmo <= 0 devuelve "Sin ritmo registrado"', () {
      expect(RulesEngine.evaluatePaceVsLevel(0, 'beginner'), "Sin ritmo registrado");
    });
  });

  group('evaluateWaterTemperature — límites', () {
    test('exactamente 18°C es aceptable, no peligroso', () {
      final r = RulesEngine.evaluateWaterTemperature(18);
      expect(r.hasAlert, false);
    });
    test('exactamente 31°C es aceptable, no peligroso', () {
      final r = RulesEngine.evaluateWaterTemperature(31);
      expect(r.hasAlert, false);
    });
    test('17.9°C es peligroso', () {
      expect(RulesEngine.evaluateWaterTemperature(17.9).hasAlert, true);
    });
    test('31.1°C es peligroso', () {
      expect(RulesEngine.evaluateWaterTemperature(31.1).hasAlert, true);
    });
    test('exactamente 25°C es óptima', () {
      expect(RulesEngine.evaluateWaterTemperature(25).title, "Temperatura Óptima");
    });
    test('exactamente 28°C es óptima', () {
      expect(RulesEngine.evaluateWaterTemperature(28).title, "Temperatura Óptima");
    });
  });

  group('evaluateSpO2 — límites', () {
    test('exactamente 90% cae en Normal (no en crítico)', () {
      expect(RulesEngine.evaluateSpO2(90).title, "Normal");
    });
    test('exactamente 91% es levemente bajo', () {
      expect(RulesEngine.evaluateSpO2(91).title, "Aviso: SpO2 Levemente Bajo");
    });
    test('exactamente 94% sigue levemente bajo', () {
      expect(RulesEngine.evaluateSpO2(94).title, "Aviso: SpO2 Levemente Bajo");
    });
    test('exactamente 95% es Normal', () {
      expect(RulesEngine.evaluateSpO2(95).title, "Normal");
    });
  });

  group('checkMaxHeartRateAlert — casos límite', () {
    test('lista vacía nunca alerta', () {
      expect(RulesEngine.checkMaxHeartRateAlert([], 20), false);
    });
    test('respeta un intervalo de lectura distinto a 1s', () {
      // 20 años -> 90% de 200 = 180. 30 lecturas cada 2s = 60s sostenidos.
      final bpms = List.filled(30, 185);
      expect(RulesEngine.checkMaxHeartRateAlert(bpms, 20, readingIntervalSeconds: 2), true);
    });
  });

  group('computeEfficiencyScore — entradas inválidas', () {
    test('FC promedio null devuelve null', () {
      expect(RulesEngine.computeEfficiencyScore(
        paceSecondsPer100m: 100, avgHeartRate: null, age: 25, level: 'beginner',
      ), null);
    });
    test('FC promedio <= 0 devuelve null', () {
      expect(RulesEngine.computeEfficiencyScore(
        paceSecondsPer100m: 100, avgHeartRate: 0, age: 25, level: 'beginner',
      ), null);
    });
    test('ritmo <= 0 devuelve null', () {
      expect(RulesEngine.computeEfficiencyScore(
        paceSecondsPer100m: 0, avgHeartRate: 120, age: 25, level: 'beginner',
      ), null);
    });
  });

  group('computeTrainingLoad / computeHrRecovery — sin datos suficientes', () {
    test('computeTrainingLoad([]) es null', () {
      expect(RulesEngine.computeTrainingLoad([]), null);
    });

    test('computeHrRecovery con menos de 2 muestras es null', () {
      final start = DateTime(2026, 1, 1);
      final session = SwimSession(
        id: 'r1',
        startTime: start,
        endTime: start.add(const Duration(minutes: 1)),
        distance: 0,
        calories: 0,
        heartRateSeries: [HeartRatePoint(time: start, bpm: 120)],
      );
      expect(RulesEngine.computeHrRecovery(session), null);
    });

    test('computeHrZoneDistribution con menos de 2 muestras es []', () {
      final start = DateTime(2026, 1, 1);
      final session = SwimSession(
        id: 'r2',
        startTime: start,
        endTime: start.add(const Duration(minutes: 1)),
        distance: 0,
        calories: 0,
        heartRateSeries: const [],
      );
      expect(RulesEngine.computeHrZoneDistribution(session, age: 25), isEmpty);
    });
  });

  group('caloriesPer100m / averageIntensityPercent — entradas inválidas', () {
    test('caloriesPer100m es null si no hay distancia', () {
      final session = SwimSession(
        id: 'c1',
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 10),
        distance: 0,
        calories: 300,
        heartRateSeries: const [],
      );
      expect(RulesEngine.caloriesPer100m(session), null);
    });

    test('caloriesPer100m es null si no hay calorías', () {
      final session = SwimSession(
        id: 'c2',
        startTime: DateTime(2026, 1, 1),
        endTime: DateTime(2026, 1, 1, 0, 10),
        distance: 1000,
        calories: 0,
        heartRateSeries: const [],
      );
      expect(RulesEngine.caloriesPer100m(session), null);
    });

    test('averageIntensityPercent es null si no hay FC promedio', () {
      expect(RulesEngine.averageIntensityPercent(null, 25), null);
    });

    test('averageIntensityPercent es null si la FC promedio es <= 0', () {
      expect(RulesEngine.averageIntensityPercent(0, 25), null);
    });
  });
}
