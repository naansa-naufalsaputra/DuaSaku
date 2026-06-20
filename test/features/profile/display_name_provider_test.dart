import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duasaku_app/features/profile/providers/display_name_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DisplayNameNotifier Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initializes with empty string when SharedPreferences is empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final name = container.read(displayNameProvider);
      expect(name, isEmpty);
    });

    test('initializes with saved name from SharedPreferences correctly', () async {
      SharedPreferences.setMockInitialValues({
        'display_name': 'Naufal',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger evaluation of provider and wait for async init
      container.read(displayNameProvider);
      await Future.delayed(const Duration(milliseconds: 50));

      final name = container.read(displayNameProvider);
      expect(name, equals('Naufal'));
    });

    test('setDisplayName updates state and saves to SharedPreferences', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(displayNameProvider.notifier);
      await notifier.setDisplayName('Saputra');

      final name = container.read(displayNameProvider);
      expect(name, equals('Saputra'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('display_name'), equals('Saputra'));
    });
  });
}
