import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:duasaku_app/core/security/security_service.dart';
import 'package:duasaku_app/features/auth/providers/auth_provider.dart';
import 'package:duasaku_app/features/auth/data/auth_repository.dart';
import 'package:duasaku_app/core/utils/logger.dart';

class FakeLogger implements AppLogger {
  @override void info(String message) {}
  @override void warning(String message, [dynamic error, StackTrace? stackTrace]) {}
  @override void error(String message, [dynamic error, StackTrace? stackTrace]) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  const localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

  final Map<String, String> secureStore = {};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (MethodCall methodCall) async {
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

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(localAuthChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'authenticate':
          return true;
        case 'getAvailableBiometrics':
          return <String>['fingerprint'];
        case 'canCheckBiometrics':
        case 'isDeviceSupported':
          return true;
        default:
          return null;
      }
    });
  });

  setUp(() {
    secureStore.clear();
  });

  group('SecurityNotifier Unit Tests', () {
    test('initial state is unlocked by default if security is not enabled', () async {
      SharedPreferences.setMockInitialValues({
        'security_enabled': false,
        'biometric_lock_enabled': false,
      });

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository()),
          loggerProvider.overrideWithValue(FakeLogger()),
        ],
      );
      addTearDown(container.dispose);

      // Kick off the provider initialization by reading it
      container.read(securityProvider);

      // Wait a moment for async _init() to finish
      await Future.delayed(const Duration(seconds: 1));

      final state = container.read(securityProvider);
      expect(state.isInitialized, isTrue);
      expect(state.isLocked, isFalse);
      expect(state.isBiometricEnabled, isFalse);
    });

    test('lockAppManually - locks app only if security and biometrics are enabled', () async {
      SharedPreferences.setMockInitialValues({
        'security_enabled': true,
        'biometric_lock_enabled': true,
      });

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository()),
          loggerProvider.overrideWithValue(FakeLogger()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(securityProvider.notifier);
      await Future.delayed(const Duration(seconds: 1));

      // Unlock it first
      notifier.unlock();
      expect(container.read(securityProvider).isLocked, isFalse);

      // Lock it manually
      notifier.lockAppManually();
      expect(container.read(securityProvider).isLocked, isTrue);
    });

    test('unlock - unlocks app', () async {
      SharedPreferences.setMockInitialValues({
        'security_enabled': true,
        'biometric_lock_enabled': true,
      });

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(AuthRepository()),
          loggerProvider.overrideWithValue(FakeLogger()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(securityProvider.notifier);
      await Future.delayed(const Duration(seconds: 1));

      // Should be locked initially by setup
      expect(container.read(securityProvider).isLocked, isTrue);

      notifier.unlock();
      expect(container.read(securityProvider).isLocked, isFalse);
    });
  });
}
