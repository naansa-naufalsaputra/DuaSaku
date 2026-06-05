import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../../features/recurring_transactions/services/recurring_notification_service.dart';
import '../../features/smart_budget_alerts/services/budget_notification_service.dart';
import '../../features/geofencing/services/geofence_sync_helper.dart';
import '../constants/app_constants.dart';
import '../local_db/app_database.dart';
import 'recurring_executor.dart';

// Unique task names
const String recurringTaskName = "com.duasaku.app.recurringTask";
const String budgetAlertQueueTaskName = "com.duasaku.app.budgetAlertQueueTask";
const String geofenceSyncTaskName = "com.duasaku.app.geofenceSyncTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case recurringTaskName:
        return await _handleRecurringSync();
      case budgetAlertQueueTaskName:
        return await _handleBudgetAlertQueueProcessing();
      case geofenceSyncTaskName:
        return await _handleGeofenceSync();
      default:
        debugPrint('[BackgroundTask] Unknown task: $task');
        return Future.value(false);
    }
  });
}

/// Handles the recurring transaction sync in the background isolate.
///
/// Creates its own [AppDatabase] instance (no Riverpod in background isolate),
/// initializes [FlutterLocalNotificationsPlugin] for execution notifications,
/// runs the [RecurringExecutor], then closes the database.
/// Returns false on failure so WorkManager retries with exponential backoff.
Future<bool> _handleRecurringSync() async {
  AppDatabase? db;
  try {
    db = AppDatabase();

    // Initialize flutter_local_notifications in background isolate.
    // The plugin works in background isolates as long as it's initialized.
    RecurringNotificationService? notificationService;
    try {
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await notificationsPlugin.initialize(settings: initSettings);
      notificationService = RecurringNotificationService(notificationsPlugin);
    } catch (e) {
      // If notification initialization fails, continue without notifications.
      debugPrint(
        '[BackgroundTask] Notification init failed (non-fatal): $e',
      );
    }

    final executor = RecurringExecutor(
      db,
      notificationService: notificationService,
    );
    final result = await executor.execute();
    debugPrint('[BackgroundTask] Recurring sync completed: $result');
    return result;
  } catch (e) {
    debugPrint('[BackgroundTask] Recurring sync failed: $e');
    return false;
  } finally {
    await db?.close();
  }
}

/// Handles budget alert queue processing in the background isolate.
///
/// Processes queued notifications that were held during quiet hours.
/// When quiet hours end, sends summary (if > 3 queued) or individual
/// notifications (if ≤ 3 queued).
///
/// Creates its own [AppDatabase] and [BudgetNotificationService] instances
/// (no Riverpod in background isolate).
/// Returns false on failure so WorkManager retries with exponential backoff.
///
/// Deep link: notification tap opens Alert Center via `duasaku://alert_center`.
/// Note: The actual route registration for `duasaku://alert_center` is handled
/// in task 13.1.
Future<bool> _handleBudgetAlertQueueProcessing() async {
  AppDatabase? db;
  try {
    db = AppDatabase();

    // Initialize flutter_local_notifications in background isolate.
    try {
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await notificationsPlugin.initialize(settings: initSettings);
    } catch (e) {
      // If notification initialization fails, continue anyway.
      // processQueuedNotifications will handle missing plugin gracefully.
      debugPrint(
        '[BackgroundTask] Notification init failed (non-fatal): $e',
      );
    }

    final notificationService = BudgetNotificationService();

    // Process queued notifications for the default local user.
    // In background isolate, Riverpod is not available, so we use
    // AppConstants.defaultUserId directly.
    await notificationService.processQueuedNotifications(
      AppConstants.defaultUserId,
    );

    debugPrint('[BackgroundTask] Budget alert queue processing completed');
    return true;
  } catch (e) {
    debugPrint('[BackgroundTask] Budget alert queue processing failed: $e');
    return false;
  } finally {
    await db?.close();
  }
}

Future<bool> _handleGeofenceSync() async {
  AppDatabase? db;
  try {
    db = AppDatabase();
    await GeofenceSyncHelper.syncGeofenceHotspots(db, AppConstants.defaultUserId);
    debugPrint('[BackgroundTask] Geofence sync task completed successfully');
    return true;
  } catch (e) {
    debugPrint('[BackgroundTask] Geofence sync task failed: $e');
    return false;
  } finally {
    await db?.close();
  }
}

class BackgroundTaskHelper {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );

    // Register recurring task to run periodically (every 15 minutes is minimum Android constraint)
    await Workmanager().registerPeriodicTask(
      "1",
      recurringTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        requiresBatteryNotLow: true,
      ),
    );

    // Register budget alert queue processing task.
    // Processes queued notifications after quiet hours end.
    // Runs every 15 minutes (minimum Android WorkManager interval).
    // Queued notifications are delivered at the next available execution window
    // after quiet hours end — not precisely at the configured end time.
    await Workmanager().registerPeriodicTask(
      "2",
      budgetAlertQueueTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        requiresBatteryNotLow: true,
      ),
    );

    // Register geofence sync task. Runs every 24 hours.
    await Workmanager().registerPeriodicTask(
      "3",
      geofenceSyncTaskName,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        requiresBatteryNotLow: true,
      ),
    );
  }
}
