import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:duasaku_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Happy Path Integration Test', () {
    testWidgets('App initialization and loading check', (tester) async {
      // Pump the main app widget
      await tester.pumpWidget(const ProviderScope(child: app.DuaSakuApp()));
      await tester.pumpAndSettle();

      // Assert that the app is initialized successfully and the root widget tree is present
      expect(find.byType(app.DuaSakuApp), findsOneWidget);
    });
  });
}
