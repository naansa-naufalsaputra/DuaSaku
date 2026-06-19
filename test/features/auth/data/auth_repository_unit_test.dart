import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duasaku_app/features/auth/data/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> secureStore = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'write':
              final args = methodCall.arguments as Map;
              secureStore[args['key'] as String] = args['value'] as String;
              return null;
            case 'read':
              final args = methodCall.arguments as Map;
              return secureStore[args['key'] as String];
            case 'delete':
              final args = methodCall.arguments as Map;
              secureStore.remove(args['key'] as String);
              return null;
            case 'deleteAll':
              secureStore.clear();
              return null;
            case 'containsKey':
              final args = methodCall.arguments as Map;
              return secureStore.containsKey(args['key'] as String);
            default:
              return null;
          }
        });
  });

  setUp(() {
    secureStore.clear();
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthRepository Unit Tests', () {
    test(
      'setPin and verifyPin - successfully creates and verifies PIN',
      () async {
        final repository = AuthRepository();
        await repository.setPin('1234');

        final hasPin = await repository.hasPinSet();
        expect(hasPin, isTrue);

        final isCorrect = await repository.verifyPin('1234');
        expect(isCorrect, isTrue);
      },
    );

    test('verifyPin - fails with incorrect PIN', () async {
      final repository = AuthRepository();
      await repository.setPin('1234');

      final isCorrect = await repository.verifyPin('9999');
      expect(isCorrect, isFalse);
    });

    test('verifyPin - rate limiting lockout behavior', () async {
      final repository = AuthRepository();
      await repository.setPin('1234');

      // 1. Fail 5 times to trigger first lockout level (30 seconds)
      for (int i = 0; i < 5; i++) {
        final verifyResult = await repository.verifyPin('9999');
        expect(verifyResult, isFalse);
      }

      // Verify lockout is active (verifyPin returns false even for correct PIN)
      final correctPinVerifyAfterLockout = await repository.verifyPin('1234');
      expect(correctPinVerifyAfterLockout, isFalse);
    });

    test(
      'completeOnboarding - updates state and sets PIN if provided',
      () async {
        final repository = AuthRepository();
        expect(repository.isOnboardingCompleted, isFalse);

        await repository.completeOnboarding(pin: '5678');
        expect(repository.isOnboardingCompleted, isTrue);

        final hasPin = await repository.hasPinSet();
        expect(hasPin, isTrue);

        final isCorrect = await repository.verifyPin('5678');
        expect(isCorrect, isTrue);
      },
    );
  });
}
