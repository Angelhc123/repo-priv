import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/models/swim_session.dart';
import 'package:coswim/models/user_profile.dart';
import 'package:coswim/screens/session_detail_screen.dart';
import 'package:coswim/widgets/charts/heart_rate_series_chart.dart';

import '../helpers/fakes.dart';
import '../helpers/fixtures.dart';
import '../helpers/pump.dart';

void main() {
  setUpAll(initSpanishDates);

  Future<void> pumpDetail(WidgetTester tester, SwimSession session, {UserProfile? profile}) async {
    final state = await buildAppState(signedIn: false, profile: profile);
    await pumpScreen(tester, SessionDetailScreen(session: session, appState: state),
        size: const Size(1400, 5000));
    await tester.pumpAndSettle();
  }

  group('sesión completa', () {
    testWidgets('el título es la fecha en español', (tester) async {
      await pumpDetail(tester, buildSession(start: DateTime(2026, 1, 15, 8, 0)));
      expect(find.textContaining('jueves 15 enero'), findsOneWidget);
    });

    testWidgets('muestra las métricas principales', (tester) async {
      await pumpDetail(tester, buildSession(distance: 1000, durationSeconds: 1200, calories: 250));
      expect(find.text('1000 m'), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
      expect(find.text('2:00 min/100m'), findsOneWidget);
      expect(find.text('250 kcal'), findsOneWidget);
      expect(find.text('25.0'), findsOneWidget); // Cal/100m
    });

    testWidgets('muestra la intensidad como % de FC máxima', (tester) async {
      await pumpDetail(tester, buildSession());
      expect(find.textContaining('% FCmáx'), findsOneWidget);
    });

    testWidgets('muestra la tarjeta de índice de eficiencia', (tester) async {
      await pumpDetail(tester, buildSession());
      expect(find.textContaining('Índice de eficiencia ·'), findsOneWidget);
    });

    testWidgets('muestra la carga de entrenamiento y la leyenda de zonas', (tester) async {
      await pumpDetail(tester, buildSession());
      expect(find.textContaining('Carga de entrenamiento ·'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Z\d \d+%$')), findsWidgets);
    });

    testWidgets('muestra la recuperación de FC', (tester) async {
      await pumpDetail(tester, buildSession());
      expect(find.text('Recuperación de FC'), findsOneWidget);
      expect(find.textContaining('últimos 2 min'), findsOneWidget);
    });

    testWidgets('incluye el gráfico de FC compartido', (tester) async {
      await pumpDetail(tester, buildSession());
      expect(find.byType(HeartRateSeriesChart), findsOneWidget);
    });

    testWidgets('muestra histograma, calorías y pasos', (tester) async {
      await pumpDetail(tester, buildSession());
      expect(find.text('Distribución de FC'), findsOneWidget);
      expect(find.text('Calorías en el Tiempo'), findsOneWidget);
      expect(find.text('Actividad (Pasos)'), findsOneWidget);
      expect(find.byType(BarChart), findsNWidgets(4)); // histograma, calorías, pasos, splits
    });

    testWidgets('con SpO2 continua no muestra la nota de ausencia', (tester) async {
      await pumpDetail(tester, buildSession());
      expect(find.textContaining('no registró SpO2'), findsNothing);
      expect(find.text('Sin serie de SpO2 registrada'), findsNothing);
    });

    testWidgets('con velocidad calcula splits y muestra la tabla', (tester) async {
      await pumpDetail(tester, buildSession(durationSeconds: 300, speedMs: 1.0));
      expect(find.textContaining('Splits estimados'), findsOneWidget);
      expect(find.text('100m'), findsWidgets);
      expect(find.text('300m'), findsWidgets);
      expect(find.text('1:40/100m'), findsNWidgets(3));
      expect(find.textContaining('Índice '), findsWidgets);
    });
  });

  group('sesión sin series', () {
    testWidgets('muestra N/A en FC, SpO2 e intensidad', (tester) async {
      await pumpDetail(tester, bareSession());
      expect(find.text('N/A'), findsNWidgets(4)); // FC prom, FC máx, SpO2, intensidad
    });

    testWidgets('índice sin datos', (tester) async {
      await pumpDetail(tester, bareSession());
      expect(find.text('Índice de eficiencia · Sin datos'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
    });

    testWidgets('no muestra carga ni recuperación', (tester) async {
      await pumpDetail(tester, bareSession());
      expect(find.textContaining('Carga de entrenamiento'), findsNothing);
      expect(find.text('Recuperación de FC'), findsNothing);
    });

    testWidgets('no muestra histograma, calorías ni pasos', (tester) async {
      await pumpDetail(tester, bareSession());
      expect(find.text('Distribución de FC'), findsNothing);
      expect(find.text('Calorías en el Tiempo'), findsNothing);
      expect(find.text('Actividad (Pasos)'), findsNothing);
    });

    testWidgets('gráfico de FC muestra el estado vacío', (tester) async {
      await pumpDetail(tester, bareSession());
      expect(find.text('Sin serie de FC registrada'), findsOneWidget);
    });

    testWidgets('SpO2 vacía muestra estado vacío y nota', (tester) async {
      await pumpDetail(tester, bareSession());
      expect(find.text('Sin serie de SpO2 registrada'), findsOneWidget);
      expect(find.textContaining('no registró SpO2'), findsOneWidget);
    });

    testWidgets('sin velocidad avisa que no hay splits', (tester) async {
      await pumpDetail(tester, bareSession());
      expect(find.textContaining('Sin datos de velocidad suficientes'), findsOneWidget);
      expect(find.textContaining('Splits estimados'), findsNothing);
    });

    testWidgets('sin distancia ni calorías Cal/100m es N/A', (tester) async {
      await pumpDetail(tester, bareSession(distance: 0, calories: 0));
      expect(find.text('--:--'), findsOneWidget);
    });
  });

  group('casos de color y valores', () {
    testWidgets('FC constante muestra caída 0 en naranja', (tester) async {
      final hr = [
        for (var i = 0; i <= 10; i++)
          HeartRatePoint(time: kStart.add(Duration(seconds: i * 30)), bpm: 140),
      ];
      final s = SwimSession(
        id: 'flat',
        startTime: kStart,
        endTime: kStart.add(const Duration(minutes: 5)),
        distance: 300,
        calories: 60,
        averageHeartRate: 140,
        maxHeartRate: 140,
        heartRateSeries: hr,
      );
      await pumpDetail(tester, s);
      final drop = find.byWidgetPredicate(
          (w) => w is Text && w.data == '0' && w.style?.fontSize == 24);
      expect(tester.widget<Text>(drop).style!.color, Colors.orange);
    });

    testWidgets('splits sin FC se pintan con índice "--"', (tester) async {
      await pumpDetail(tester, buildSession(withHr: false, durationSeconds: 200));
      expect(find.text('Índice --'), findsNWidgets(2));
      expect(find.text('-- bpm'), findsNWidgets(2));
    });

    for (final level in ['beginner', 'intermediate', 'advanced', 'competitive']) {
      testWidgets('se renderiza sin errores para nivel $level', (tester) async {
        await pumpDetail(tester, buildSession(),
            profile: UserProfile(age: 30, level: level, useMockData: false));
        expect(tester.takeException(), isNull);
        expect(find.byType(SessionDetailScreen), findsOneWidget);
      });
    }
  });
}
