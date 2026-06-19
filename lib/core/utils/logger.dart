import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Abstraksi logger terpusat untuk aplikasi.
/// Mempermudah integrasi dengan layanan analitik (seperti Sentry/Crashlytics) di masa depan.
abstract class AppLogger {
  void info(String message);
  void warning(String message, [dynamic error, StackTrace? stackTrace]);
  void error(String message, [dynamic error, StackTrace? stackTrace]);
}

/// Implementasi Logger untuk konsol menggunakan [debugPrint].
class ConsoleLogger implements AppLogger {
  @override
  void info(String message) {
    debugPrint('[INFO] $message');
  }

  @override
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[WARN] $message${error != null ? ' - Error: $error' : ''}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  @override
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message${error != null ? ' - Error: $error' : ''}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }
}

/// Implementasi Logger untuk production dengan Sentry.
class ProductionLogger implements AppLogger {
  @override
  void info(String message) {
    Sentry.captureMessage(message, level: SentryLevel.info);
  }

  @override
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('log_level', 'warning');
          scope.setContexts('message', message);
        },
      );
    } else {
      Sentry.captureMessage(message, level: SentryLevel.warning);
    }
  }

  @override
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error != null) {
      Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('log_level', 'error');
          scope.setContexts('message', message);
        },
      );
    } else {
      Sentry.captureMessage(message, level: SentryLevel.error);
    }
  }
}

/// Provider Riverpod untuk logger.
/// Menggunakan ProductionLogger di release mode, ConsoleLogger di debug.
final loggerProvider = Provider<AppLogger>((ref) {
  return kReleaseMode ? ProductionLogger() : ConsoleLogger();
});
