import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lottie/lottie.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/routing/app_router.dart';
import 'core/background/background_task_helper.dart';
import 'features/geofencing/services/geofence_service.dart';
import 'core/security/security_service.dart';
import 'features/transactions/services/notification_parser_service.dart';
import 'core/config/env.dart';
import 'core/services/balance_integrity_provider.dart';
import 'features/transactions/providers/transaction_event_handlers_provider.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/screens/pin_auth_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'services/service_providers.dart';

// StateProvider to track whether the app was opened from a home screen widget click
final widgetLaunchProvider = StateProvider<bool>((ref) => false);

/// Stream controller for notification tap payloads.
/// When a notification is tapped, the payload URI is added to this stream
/// so the app can navigate accordingly.
final StreamController<String> notificationTapController =
    StreamController<String>.broadcast();

/// Handles the notification tap response from flutter_local_notifications.
/// Parses the payload and adds it to the stream for the app to handle.
@pragma('vm:entry-point')
void onNotificationTapGlobal(NotificationResponse response) {
  final payload = response.payload;
  if (payload != null && payload.isNotEmpty) {
    notificationTapController.add(payload);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Sentry for production crash reporting
  await SentryFlutter.init((options) {
    options.dsn =
        'https://your-sentry-dsn@sentry.io/project-id'; // Todo: Replace with actual DSN
    options.environment = kReleaseMode ? 'production' : 'development';
    options.tracesSampleRate = 0.1; // 10% performance monitoring
    options.enableAutoSessionTracking = true;
    // Only capture in release mode by default
    options.beforeSend = (event, hint) {
      if (kDebugMode) return null; // Skip Sentry in debug
      return event;
    };
  }, appRunner: _runApp);
}

void _runApp() async {
  // Setup Global Error Logging Interceptors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logGlobalError(
      title: 'FLUTTER FRAMEWORK ERROR',
      emoji: '🚨',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logGlobalError(
      title: 'UNCAUGHT ASYNCHRONOUS ERROR',
      emoji: '⚡',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logGlobalError(
      title: 'UNCAUGHT ASYNCHRONOUS ERROR',
      emoji: '⚡',
      error: error,
      stackTrace: stack,
    );
    return true; // Mark as handled
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return FriendlyErrorWidget(details: details);
  };

  await EasyLocalization.ensureInitialized();

  // Load environment variables
  await Env.init();

  // Initialize flutter_local_notifications with tap handler
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: onNotificationTapGlobal,
  );

  // Check if app was launched from a notification tap
  final launchDetails = await flutterLocalNotificationsPlugin
      .getNotificationAppLaunchDetails();
  final initialNotificationPayload =
      launchDetails?.didNotificationLaunchApp == true
      ? launchDetails?.notificationResponse?.payload
      : null;

  // Initialize background tasks
  await BackgroundTaskHelper.initialize();

  // Initialize location monitoring and local notifications
  await GeofenceService.instance.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('id')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: ProviderScope(
        child: DuaSakuApp(
          initialNotificationPayload: initialNotificationPayload,
        ),
      ),
    ),
  );
}

class DuaSakuApp extends ConsumerStatefulWidget {
  const DuaSakuApp({super.key, this.initialNotificationPayload});

  final String? initialNotificationPayload;

  @override
  ConsumerState<DuaSakuApp> createState() => _DuaSakuAppState();
}

class _DuaSakuAppState extends ConsumerState<DuaSakuApp> {
  StreamSubscription<Uri?>? _widgetSubscription;
  StreamSubscription<String>? _notificationTapSubscription;
  bool _initialNotificationHandled = false;

  @override
  void initState() {
    super.initState();
    _initHomeWidget();
    _initNotificationTapListener();
    _preCacheLottieAnimations();
    // Silent background ML Kit model initialization
    Future.microtask(() {
      if (mounted) {
        ref.read(smartInputMlServiceProvider).initializeSilently();
        // Run balance integrity check on startup
        _runBalanceIntegrityCheck(ref);
        // Initialize transaction event handlers
        _initTransactionEventHandlers(ref);
      }
    });
  }

  void _preCacheLottieAnimations() {
    try {
      AssetLottie('assets/animations/empty_alerts.json').load();
      AssetLottie('assets/animations/success.json').load();
    } catch (e) {
      debugPrint('[LottiePreCache] Error pre-caching animations: $e');
    }
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    _notificationTapSubscription?.cancel();
    super.dispose();
  }

  void _initHomeWidget() {
    // Listen for widget clicks when the app is already in memory
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetClick);

    // Check if the app was initially launched by tapping the widget
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetClick);
  }

  void _handleWidgetClick(Uri? uri) {
    if (uri == null) return;

    if (uri.host == 'new_transaction' ||
        uri.toString() == 'duasaku://new_transaction') {
      ref.read(widgetLaunchProvider.notifier).state = true;
      ref.read(routerProvider).go('/home');
    } else if (uri.host == 'recurring_transactions') {
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        // Navigate to detail view for specific recurring transaction
        ref.read(routerProvider).go('/recurring-transactions/$id');
      } else {
        // Navigate to recurring transactions list
        ref.read(routerProvider).go('/recurring-transactions');
      }
    } else if (uri.host == 'goals') {
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        // Navigate to goal detail view
        ref.read(routerProvider).go('/goals/$id');
      } else {
        // Navigate to goals list
        ref.read(routerProvider).go('/goals');
      }
    } else if (uri.host == 'alert_center') {
      final alertId = uri.queryParameters['id'];
      if (alertId != null && alertId.isNotEmpty) {
        // Navigate to Alert Center and highlight specific alert
        ref.read(routerProvider).go('/alert-center?alertId=$alertId');
      } else {
        // Navigate to Alert Center
        ref.read(routerProvider).go('/alert-center');
      }
    } else if (uri.host == 'wallet_detail') {
      final id = uri.queryParameters['id'];
      if (id != null && id.isNotEmpty) {
        ref.read(routerProvider).go('/wallets/$id');
      } else {
        ref.read(routerProvider).go('/manage-wallets');
      }
    }
  }

  void _initNotificationTapListener() {
    // Listen for notification taps while the app is running
    _notificationTapSubscription = notificationTapController.stream.listen(
      _handleNotificationPayload,
    );

    // Handle the initial notification payload if the app was launched from a notification
    if (widget.initialNotificationPayload != null &&
        !_initialNotificationHandled) {
      _initialNotificationHandled = true;
      // Delay to ensure router is ready after app initialization
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _handleNotificationPayload(widget.initialNotificationPayload!);
        }
      });
    }
  }

  /// Handles a notification payload by parsing it as a URI and navigating.
  void _handleNotificationPayload(String payload) {
    final uri = Uri.tryParse(payload);
    if (uri == null || uri.scheme != 'duasaku') return;

    _handleWidgetClick(uri);
  }

  /// Runs balance integrity check in background to detect/repair wallet balance drift.
  void _runBalanceIntegrityCheck(WidgetRef ref) async {
    try {
      final service = ref.read(balanceIntegrityServiceProvider);
      final discrepancies = await service.checkAllWallets();

      if (discrepancies.isNotEmpty) {
        debugPrint(
          '[BalanceIntegrity] Found ${discrepancies.length} discrepancies, repairing...',
        );
        final repairedCount = await service.repairAllDiscrepancies(
          discrepancies,
        );
        debugPrint('[BalanceIntegrity] Repaired $repairedCount wallets');
      } else {
        debugPrint('[BalanceIntegrity] No balance discrepancies found');
      }
    } catch (e) {
      debugPrint('[BalanceIntegrity] Error during balance check: $e');
    }
  }

  /// Initialize transaction event handlers to listen for side-effects.
  void _initTransactionEventHandlers(WidgetRef ref) {
    try {
      // Access the provider to initialize and register event handlers
      ref.read(transactionEventHandlersProvider);
      debugPrint('[EventHandlers] Transaction event handlers initialized');
    } catch (e) {
      debugPrint('[EventHandlers] Error initializing event handlers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeNotifierProvider);
    final lightDetails = ThemePresets.getDetails(themeState.preset, false);
    final darkDetails = ThemePresets.getDetails(themeState.preset, true);

    // Initialize Notification Parser Service to listen to Native Events
    ref.watch(notificationParserProvider);

    return MaterialApp.router(
      title: 'DuaSaku',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: lightDetails.themeData,
      darkTheme: darkDetails.themeData,
      themeMode: themeState.themeMode,
      routerConfig: router,
      builder: (context, child) {
        return SecurityWrapper(child: child ?? const SizedBox());
      },
    );
  }
}

class SecurityWrapper extends ConsumerWidget {
  final Widget child;
  const SecurityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final securityState = ref.watch(securityProvider);
    final authRepo = ref.watch(authRepositoryProvider);

    if (!securityState.isInitialized) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (securityState.isSecurityEnabled &&
        securityState.isLocked &&
        authRepo.isOnboardingCompleted) {
      return const PinAuthScreen();
    }

    if (securityState.isTimeTampered) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 80,
                ),
                const SizedBox(height: 24),
                Text(
                  'security.time_tamper_title'.tr(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'security.time_tamper_message'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size(88, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    ref.read(securityProvider.notifier).verifyNtpTime();
                  },
                  child: Text(
                    'security.recheck_button'.tr(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return child;
  }
}

void _logGlobalError({
  required String title,
  required String emoji,
  required Object error,
  required StackTrace? stackTrace,
}) {
  // In release mode, send to Sentry
  if (kReleaseMode) {
    Sentry.captureException(error, stackTrace: stackTrace);
    return; // Don't log to console in release
  }

  // Debug mode: detailed console logging
  final buffer = StringBuffer();
  buffer.writeln(
    '======================================================================',
  );
  buffer.writeln('$emoji $title');
  buffer.writeln(
    '----------------------------------------------------------------------',
  );
  buffer.writeln('Error: $error');
  if (stackTrace != null) {
    buffer.writeln(
      '----------------------------------------------------------------------',
    );
    buffer.writeln('Stack Trace:');
    buffer.writeln(stackTrace);
  }
  buffer.writeln(
    '======================================================================',
  );
  debugPrint(buffer.toString());
}

class FriendlyErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const FriendlyErrorWidget({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: theme.colorScheme.error,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'error.title'.tr(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'error.message'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.error.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SelectableText(
                      details.exceptionAsString(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
