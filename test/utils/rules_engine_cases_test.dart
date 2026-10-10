import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/utils/rules_engine.dart';

import '../helpers/fixtures.dart';

/// Sesión cuya serie de FC es exactamente [bpms], una muestra cada [step] s.
SwimSession _hrSession(List<int> bpms, {int step = 60}) {
  final series = [
    for (var i = 0; i < bpms.length; i++)
      HeartRatePoint(time: kStart.add(Duration(seconds: i * step)), bpm: bpms[i]),
  ];
  return SwimSession(
    id: 'hr',
    startTime: kStart,
    endTime: kStart.add(Duration(seconds: (bpms.length - 1) * step)),
    distance: 1000,
    calories: 200,
    heartRateSeries: series,
  );
}

void main() {
  group('getMaxHeartRate', () {
    for (final (age, expected) in const [(0, 220), (10, 210), (22, 198), (40, 180), (65, 155), (100, 120)]) {
      test('edad $age → $expected', () {
        expect(RulesEngine.getMaxHeartRate(age), expected);
      });
    }
  });

  group('referenceSpeedMetersPerMinute', () {
    const cases = <(String, double, String)>[
      ('beginner', 40, 'Principiante'),
      ('intermediate', 48, 'Intermedio'),
      ('advanced', 68, 'Avanzado'),
      ('competitive', 85, 'Competitivo'),
      ('ADVANCED', 68, 'Avanzado'),
      ('Intermediate', 48, 'Intermedio'),
      ('desconocido', 40, 'Principiante'),
      ('', 40, 'Principiante'),
    ];
    for (final (level, speed, label) in cases) {
      test('nivel "$level" → $speed m/min ($label)', () {
        final ref = RulesEngine.referenceSpeedMetersPerMinute(level);
        expect(ref.metersPerMinute, speed);
        expect(ref.label, label);
      });
    }
  });

  group('computeEfficiencyScore', () {
    test('ritmo de referencia a 75% de FC máx da 100', () {
      // principiante: 40 m/min → 150 s/100m; edad 20 → FC máx 200 → 75% = 150.
      final score = RulesEngine.computeEfficiencyScore(
        paceSecondsPer100m: 150,
        avgHeartRate: 150,
        age: 20,
        level: 'beginner',
      );
      expect(score, 100);
    });

    test('el doble de rápido con el mismo esfuerzo da 200', () {
      expect(
        RulesEngine.computeEfficiencyScore(
            paceSecondsPer100m: 75, avgHeartRate: 150, age: 20, level: 'beginner'),
        200,
      );
    });

    test('mismo ritmo con el doble de FC relativa da 50', () {
      expect(
        RulesEngine.computeEfficiencyScore(
            paceSecondsPer100m: 150, avgHeartRate: 300, age: 20, level: 'beginner'),
        50,
      );
    });

    test('un nivel más alto exige más y baja el índice', () {
      final beginner = RulesEngine.computeEfficiencyScore(
          paceSecondsPer100m: 120, avgHeartRate: 150, age: 20, level: 'beginner')!;
      final competitive = RulesEngine.computeEfficiencyScore(
          paceSecondsPer100m: 120, avgHeartRate: 150, age: 20, level: 'competitive')!;
      expect(competitive, lessThan(beginner));
    });

    test('ritmo 0 devuelve null', () {
      expect(
        RulesEngine.computeEfficiencyScore(
            paceSecondsPer100m: 0, avgHeartRate: 150, age: 20, level: 'beginner'),
        isNull,
      );
    });

    test('ritmo negativo devuelve null', () {
      expect(
        RulesEngine.computeEfficiencyScore(
            paceSecondsPer100m: -5, avgHeartRate: 150, age: 20, level: 'beginner'),
        isNull,
      );
    });

    test('sin FC devuelve null', () {
      expect(
        RulesEngine.computeEfficiencyScore(
            paceSecondsPer100m: 120, avgHeartRate: null, age: 20, level: 'beginner'),
        isNull,
      );
    });

    test('FC 0 devuelve null', () {
      expect(
        RulesEngine.computeEfficiencyScore(
            paceSecondsPer100m: 120, avgHeartRate: 0, age: 20, level: 'beginner'),
        isNull,
      );
    });

    test('edad que deja FC máx en 0 devuelve null', () {
      expect(
        RulesEngine.computeEfficiencyScore(
            paceSecondsPer100m: 120, avgHeartRate: 140, age: 220, level: 'beginner'),
        isNull,
      );
    });
  });

  group('evaluateEfficiencyScore', () {
    const cases = <(int?, String, Color)>[
      (null, 'Sin datos', Colors.grey),
      (200, 'Excelente', Colors.green),
      (120, 'Excelente', Colors.green),
      (119, 'Estable en tu nivel', Colors.amber),
      (100, 'Estable en tu nivel', Colors.amber),
      (90, 'Estable en tu nivel', Colors.amber),
      (89, 'Por debajo de tu referencia', Colors.orange),
      (10, 'Por debajo de tu referencia', Colors.orange),
    ];
    for (final (score, title, color) in cases) {
      test('índice $score → "$title"', () {
        final r = RulesEngine.evaluateEfficiencyScore(score);
        expect(r.title, title);
        expect(r.color, color);
        expect(r.hasAlert, isFalse);
        if (score != null) expect(r.description, contains('$score'));
      });
    }
  });

  group('getHeartRateZone (edad 20, FC máx 200)', () {
    const cases = <(int, int)>[
      (0, 0), (99, 0), (100, 1), (119, 1), (120, 2), (139, 2),
      (140, 3), (159, 3), (160, 4), (179, 4), (180, 5), (230, 5),
    ];
    for (final (bpm, zone) in cases) {
      test('$bpm bpm → zona $zone', () {
        expect(RulesEngine.getHeartRateZone(bpm, 20), zone);
      });
    }

    test('edad que deja FC máx ≤ 0 siempre devuelve zona 0', () {
      expect(RulesEngine.getHeartRateZone(150, 230), 0);
    });
  });

  group('getZoneName / getZoneDescription / getZoneColor', () {
    const names = {
      0: 'Reposo / Muy baja intensidad',
      1: 'Recuperación / Calentamiento',
      2: 'Resistencia básica (Aeróbico)',
      3: 'Aeróbico moderado',
      4: 'Umbral anaeróbico',
      5: 'Máximo esfuerzo',
    };
    final colors = {
      0: Colors.blueGrey.shade300,
      1: Colors.green.shade400,
      2: Colors.lightGreen,
      3: Colors.amber,
      4: Colors.orange,
      5: Colors.red,
    };
    for (final zone in names.keys) {
      test('zona $zone tiene nombre, descripción y color propios', () {
        expect(RulesEngine.getZoneName(zone), names[zone]);
        expect(RulesEngine.getZoneDescription(zone), isNotEmpty);
        expect(RulesEngine.getZoneColor(zone), colors[zone]);
      });
    }

    test('zona fuera de rango se trata como reposo', () {
      expect(RulesEngine.getZoneName(9), names[0]);
      expect(RulesEngine.getZoneDescription(-1), RulesEngine.getZoneDescription(0));
      expect(RulesEngine.getZoneColor(42), colors[0]);
    });

    test('las descripciones de las 6 zonas son todas distintas', () {
      final descs = {for (var z = 0; z <= 5; z++) RulesEngine.getZoneDescription(z)};
      expect(descs.length, 6);
    });
  });

  group('computeHrZoneDistribution', () {
    test('serie de una sola zona da 100% en esa zona', () {
      final zones = RulesEngine.computeHrZoneDistribution(_hrSession([150, 150, 150]), age: 20);
      expect(zones.length, 1);
      expect(zones.single.zone, 3);
      expect(zones.single.percentage, 100);
      expect(zones.single.duration, const Duration(minutes: 2));
    });

    test('mitad en zona 2 y mitad en zona 4', () {
      final zones =
          RulesEngine.computeHrZoneDistribution(_hrSession([130, 130, 170, 170]), age: 20);
      // Intervalos: 130-130 (Z2), 130-170 → 150 (Z3), 170-170 (Z4).
      expect(zones.map((z) => z.zone), [2, 3, 4]);
      for (final z in zones) {
        expect(z.percentage, closeTo(100 / 3, 0.001));
      }
    });

    test('las zonas salen ordenadas de menor a mayor', () {
      final zones =
          RulesEngine.computeHrZoneDistribution(_hrSession([190, 190, 90, 90]), age: 20);
      final ordered = zones.map((z) => z.zone).toList();
      expect(ordered, [...ordered]..sort());
    });

    test('ignora intervalos con tiempo no creciente', () {
      final s = SwimSession(
        id: 'dup',
        startTime: kStart,
        endTime: kStart.add(const Duration(minutes: 1)),
        distance: 100,
        calories: 10,
        heartRateSeries: [
          HeartRatePoint(time: kStart, bpm: 150),
          HeartRatePoint(time: kStart, bpm: 190),
          HeartRatePoint(time: kStart.add(const Duration(minutes: 1)), bpm: 150),
        ],
      );
      final zones = RulesEngine.computeHrZoneDistribution(s, age: 20);
      // 0 s entre las dos primeras; solo cuenta 190→150 = 170 (Z4).
      expect(zones.single.zone, 4);
    });

    test('todas las muestras en el mismo instante devuelve vacío', () {
      final s = SwimSession(
        id: 'same',
        startTime: kStart,
        endTime: kStart,
        distance: 0,
        calories: 0,
        heartRateSeries: [
          HeartRatePoint(time: kStart, bpm: 150),
          HeartRatePoint(time: kStart, bpm: 160),
        ],
      );
      expect(RulesEngine.computeHrZoneDistribution(s, age: 20), isEmpty);
    });

    test('la suma de porcentajes es 100', () {
      final zones = RulesEngine.computeHrZoneDistribution(buildSession(), age: 30);
      final total = zones.fold<double>(0, (a, z) => a + z.percentage);
      expect(total, closeTo(100, 0.0001));
    });
  });

  group('computeTrainingLoad', () {
    test('lista vacía devuelve null', () {
      expect(RulesEngine.computeTrainingLoad(const []), isNull);
    });

    test('la zona 0 no suma carga', () {
      expect(
        RulesEngine.computeTrainingLoad(
            const [ZoneTime(zone: 0, duration: Duration(minutes: 60), percentage: 100)]),
        0,
      );
    });

    test('10 min en zona 5 = 50', () {
      expect(
        RulesEngine.computeTrainingLoad(
            const [ZoneTime(zone: 5, duration: Duration(minutes: 10), percentage: 100)]),
        50,
      );
    });

    test('suma ponderada de varias zonas', () {
      final load = RulesEngine.computeTrainingLoad(const [
        ZoneTime(zone: 1, duration: Duration(minutes: 10), percentage: 25),
        ZoneTime(zone: 2, duration: Duration(minutes: 10), percentage: 25),
        ZoneTime(zone: 3, duration: Duration(minutes: 20), percentage: 50),
      ]);
      expect(load, 10 + 20 + 60);
    });

    test('considera fracciones de minuto', () {
      expect(
        RulesEngine.computeTrainingLoad(
            const [ZoneTime(zone: 2, duration: Duration(seconds: 90), percentage: 100)]),
        3,
      );
    });
  });

  group('evaluateTrainingLoad', () {
    const cases = <(double?, String, Color)>[
      (null, 'Sin datos', Colors.grey),
      (0, 'Carga suave', Colors.green),
      (29.9, 'Carga suave', Colors.green),
      (30, 'Carga moderada', Colors.lightGreen),
      (59.9, 'Carga moderada', Colors.lightGreen),
      (60, 'Carga alta', Colors.orange),
      (99.9, 'Carga alta', Colors.orange),
      (100, 'Carga muy alta', Colors.red),
      (350, 'Carga muy alta', Colors.red),
    ];
    for (final (load, title, color) in cases) {
      test('carga $load → "$title"', () {
        final r = RulesEngine.evaluateTrainingLoad(load);
        expect(r.title, title);
        expect(r.color, color);
        if (load != null) expect(r.description, contains('${load.round()}'));
      });
    }
  });

  group('computeHrRecovery', () {
    test('menos de 2 muestras devuelve null', () {
      expect(RulesEngine.computeHrRecovery(_hrSession([150])), isNull);
    });

    test('pico al medio y bajada al final', () {
      // muestras cada 60 s; ventana de 2 min = últimas 3 muestras (120, 110, 100).
      final r = RulesEngine.computeHrRecovery(_hrSession([130, 170, 150, 120, 110, 100]))!;
      expect(r.peakBpm, 170);
      expect(r.finalAvgBpm, 110);
      expect(r.dropBpm, 60);
    });

    test('ventana personalizada más corta', () {
      final r = RulesEngine.computeHrRecovery(
        _hrSession([170, 150, 120, 100]),
        window: const Duration(seconds: 30),
      )!;
      expect(r.finalAvgBpm, 100);
      expect(r.dropBpm, 70);
    });

    test('si el pico está al final, la ventana final lo incluye', () {
      // cutoff = 180 s - 2 min = 60 s → promedio de 110, 120, 180 = 137.
      final r = RulesEngine.computeHrRecovery(_hrSession([100, 110, 120, 180]))!;
      expect(r.peakBpm, 180);
      expect(r.finalAvgBpm, 137);
      expect(r.dropBpm, 43);
    });

    test('pulso constante da caída 0', () {
      final r = RulesEngine.computeHrRecovery(_hrSession([140, 140, 140, 140]))!;
      expect(r.dropBpm, 0);
    });
  });

  group('caloriesPer100m', () {
    test('300 kcal en 1500 m = 20 kcal/100m', () {
      expect(RulesEngine.caloriesPer100m(bareSession(distance: 1500, calories: 300)), 20);
    });

    test('sin distancia devuelve null', () {
      expect(RulesEngine.caloriesPer100m(bareSession(distance: 0)), isNull);
    });

    test('sin calorías devuelve null', () {
      expect(RulesEngine.caloriesPer100m(bareSession(calories: 0)), isNull);
    });
  });

  group('averageIntensityPercent', () {
    test('150 bpm a los 20 años = 75%', () {
      expect(RulesEngine.averageIntensityPercent(150, 20), 75);
    });

    test('FC nula devuelve null', () {
      expect(RulesEngine.averageIntensityPercent(null, 20), isNull);
    });

    test('FC 0 devuelve null', () {
      expect(RulesEngine.averageIntensityPercent(0, 20), isNull);
    });

    test('edad que deja FC máx en 0 devuelve null', () {
      expect(RulesEngine.averageIntensityPercent(120, 220), isNull);
    });
  });

  group('checkMaxHeartRateAlert', () {
    test('lista vacía no alerta', () {
      expect(RulesEngine.checkMaxHeartRateAlert(const [], 20), isFalse);
    });

    test('exactamente en el 90% no cuenta (debe superarlo)', () {
      expect(RulesEngine.checkMaxHeartRateAlert(List.filled(100, 180), 20), isFalse);
    });

    test('59 lecturas seguidas arriba no alcanzan', () {
      expect(RulesEngine.checkMaxHeartRateAlert(List.filled(59, 190), 20), isFalse);
    });

    test('una bajada reinicia el conteo', () {
      final bpms = [...List.filled(40, 190), 150, ...List.filled(40, 190)];
      expect(RulesEngine.checkMaxHeartRateAlert(bpms, 20), isFalse);
    });

    test('con lecturas cada 10 s bastan 6 seguidas', () {
      expect(
        RulesEngine.checkMaxHeartRateAlert(List.filled(6, 190), 20, readingIntervalSeconds: 10),
        isTrue,
      );
    });

    test('con lecturas cada 10 s, 5 seguidas no alcanzan', () {
      expect(
        RulesEngine.checkMaxHeartRateAlert(List.filled(5, 190), 20, readingIntervalSeconds: 10),
        isFalse,
      );
    });

    test('con lecturas cada 7 s se redondea hacia arriba (9 lecturas)', () {
      expect(
        RulesEngine.checkMaxHeartRateAlert(List.filled(8, 190), 20, readingIntervalSeconds: 7),
        isFalse,
      );
      expect(
        RulesEngine.checkMaxHeartRateAlert(List.filled(9, 190), 20, readingIntervalSeconds: 7),
        isTrue,
      );
    });
  });

  group('evaluateSpO2', () {
    const cases = <(double?, String, bool)>[
      (null, 'Sin datos', false),
      (80, 'Urgente: SpO2 Crítico', true),
      (89.9, 'Urgente: SpO2 Crítico', true),
      (91, 'Aviso: SpO2 Levemente Bajo', true),
      (92.5, 'Aviso: SpO2 Levemente Bajo', true),
      (94, 'Aviso: SpO2 Levemente Bajo', true),
      (95, 'Normal', false),
      (100, 'Normal', false),
    ];
    for (final (spo2, title, alert) in cases) {
      test('SpO2 $spo2 → "$title"', () {
        final r = RulesEngine.evaluateSpO2(spo2);
        expect(r.title, title);
        expect(r.hasAlert, alert);
      });
    }
  });

  group('evaluateWaterTemperature', () {
    const cases = <(double?, String, bool)>[
      (null, 'Dato no disponible', false),
      (10, 'Temperatura fuera de rango', true),
      (17.9, 'Temperatura fuera de rango', true),
      (18, 'Temperatura Aceptable', false),
      (24.9, 'Temperatura Aceptable', false),
      (25, 'Temperatura Óptima', false),
      (28, 'Temperatura Óptima', false),
      (28.1, 'Temperatura Aceptable', false),
      (31, 'Temperatura Aceptable', false),
      (31.1, 'Temperatura fuera de rango', true),
    ];
    for (final (temp, title, alert) in cases) {
      test('$temp °C → "$title"', () {
        final r = RulesEngine.evaluateWaterTemperature(temp);
        expect(r.title, title);
        expect(r.hasAlert, alert);
      });
    }
  });

  group('evaluatePaceVsLevel', () {
    const cases = <(double, String, String)>[
      (160, 'beginner', 'Normal para principiante'),
      (140, 'beginner', 'más rápido de lo esperado'),
      (160, 'intermediate', 'Un poco lento'),
      (150, 'intermediate', 'rango óptimo para nivel intermedio'),
      (105, 'intermediate', 'rango óptimo para nivel intermedio'),
      (100, 'intermediate', 'nivel avanzado'),
      (110, 'advanced', 'Más lento del rango avanzado'),
      (90, 'advanced', 'rango óptimo de nivel avanzado'),
      (70, 'advanced', 'nivel competitivo'),
      (80, 'competitive', 'Por debajo del nivel competitivo'),
      (75, 'competitive', 'Por debajo del nivel competitivo'),
      (60, 'competitive', 'élite'),
      (100, 'COMPETITIVE', 'Por debajo del nivel competitivo'),
      (100, 'otro', 'Ritmo registrado'),
    ];
    for (final (pace, level, fragment) in cases) {
      test('$pace s/100m como "$level" menciona "$fragment"', () {
        expect(RulesEngine.evaluatePaceVsLevel(pace, level), contains(fragment));
      });
    }

    test('ritmo 0 dice "Sin ritmo registrado"', () {
      expect(RulesEngine.evaluatePaceVsLevel(0, 'beginner'), 'Sin ritmo registrado');
    });

    test('formatea el ritmo como m:ss/100m', () {
      expect(RulesEngine.evaluatePaceVsLevel(125, 'otro'), 'Ritmo registrado: 2:05/100m.');
    });
  });
}
