import 'package:flutter_test/flutter_test.dart';
import 'package:coswim/main.dart';
import 'package:coswim/services/app_state.dart';

void main() {
  testWidgets('CoSwim app starts smoke test', (WidgetTester tester) async {
    final appState = AppState();
    // Simply verify MyApp can be instantiated and pumped without errors
    await tester.pumpWidget(MyApp(appState: appState));
    expect(find.byType(MyApp), findsOneWidget);
  });
}
