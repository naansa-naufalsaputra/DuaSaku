import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '../../../core/local_db/app_database.dart';
import '../domain/models/budget_alert_model.dart';

/// Service responsible for sending push notifications for budget alerts.
///
/// Handles quiet hours detection, notification queuing, and batch delivery.
/// Configures the "Budget Alerts" notification channel with high priority.
class BudgetNotificationService {
  BudgetNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    AppDatabase? db,
  }) : _notifications =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
       _db = db ?? AppDatabase();

  final FlutterLocalNotificationsPlugin _notifications;
  final AppDatabase _db;

  static const String channelId = 'budget_alerts';
  static const String channelName = 'Budget Alerts';
  static const String channelDescription =
      'Notifications for budget threshold and prediction alerts';

  /// Android notification details configured with high priority.
  static const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      );

  /// iOS notification details.
  static const DarwinNotificationDetails iosNotificationDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

  /// Combined notification details for all platforms.
  static const NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
    iOS: iosNotificationDetails,
  );

  /// Builds the deep link payload for notification tap handling.
  ///
  /// The payload is a `duasaku://alert_center?id=<alertId>` URI that
  /// navigates to the Alert Center and highlights the relevant alert.
  String buildPayload(String alertId) {
    return 'duasaku://alert_center?id=$alertId';
  }

  /// Generates a unique notification ID from the alert ID.
  int _generateNotificationId(String alertId) {
    return alertId.hashCode;
  }

  /// Checks if the current time is within the quiet hours range.
  bool isTimeInQuietHours(DateTime time, String startStr, String endStr) {
    final startParts = startStr.split(':');
    final endParts = endStr.split(':');
    if (startParts.length != 2 || endParts.length != 2) return false;

    final startHour = int.tryParse(startParts[0]) ?? 0;
    final startMin = int.tryParse(startParts[1]) ?? 0;
    final endHour = int.tryParse(endParts[0]) ?? 0;
    final endMin = int.tryParse(endParts[1]) ?? 0;

    final currentHour = time.hour;
    final currentMin = time.minute;

    final currentVal = currentHour * 60 + currentMin;
    final startVal = startHour * 60 + startMin;
    final endVal = endHour * 60 + endMin;

    if (startVal <= endVal) {
      return currentVal >= startVal && currentVal <= endVal;
    } else {
      return currentVal >= startVal || currentVal <= endVal;
    }
  }

  Future<List<String>> _getNotifiedAlertIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('notified_alert_ids') ?? [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _markAlertAsNotified(String alertId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('notified_alert_ids') ?? [];
      if (!list.contains(alertId)) {
        list.add(alertId);
        await prefs.setStringList('notified_alert_ids', list);
      }
    } catch (_) {}
  }

  /// Sends a push notification for a budget alert, respecting quiet hours.
  ///
  /// If quiet hours are active, the notification is queued for later delivery.
  /// If the master toggle is disabled, no notification is sent.
  Future<void> sendAlertNotification({
    required BudgetAlertModel alert,
    required String userId,
  }) async {
    try {
      final query = _db.select(_db.budgetAlertPreferences)
        ..where((t) => t.userId.equals(userId) & t.categoryId.isNull());
      final prefsRow = await query.getSingleOrNull();

      if (prefsRow != null) {
        if (!prefsRow.isEnabled) {
          return;
        }

        final quietHoursStart = prefsRow.quietHoursStart;
        final quietHoursEnd = prefsRow.quietHoursEnd;
        if (quietHoursStart != null && quietHoursEnd != null) {
          final now = DateTime.now();
          if (isTimeInQuietHours(now, quietHoursStart, quietHoursEnd)) {
            return;
          }
        }
      }
    } catch (_) {}

    final title = alert.categoryName ?? 'Budget Alert';
    final body = alert.message;
    final payload = buildPayload(alert.id);

    await _notifications.show(
      id: _generateNotificationId(alert.id),
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );

    await _markAlertAsNotified(alert.id);
  }

  /// Processes queued notifications after quiet hours end.
  ///
  /// If queue > 3: sends summary notification.
  /// If queue <= 3: sends individual notifications with 10s interval.
  Future<void> processQueuedNotifications(String userId) async {
    try {
      final query = _db.select(_db.budgetAlertPreferences)
        ..where((t) => t.userId.equals(userId) & t.categoryId.isNull());
      final prefsRow = await query.getSingleOrNull();

      if (prefsRow != null) {
        final quietHoursStart = prefsRow.quietHoursStart;
        final quietHoursEnd = prefsRow.quietHoursEnd;
        if (quietHoursStart != null && quietHoursEnd != null) {
          final now = DateTime.now();
          if (isTimeInQuietHours(now, quietHoursStart, quietHoursEnd)) {
            return;
          }
        }
      }

      final alertsQuery = _db.select(_db.budgetAlerts)
        ..where((t) => t.userId.equals(userId) & t.isRead.equals(false));
      final alertRows = await alertsQuery.get();

      final notifiedIds = await _getNotifiedAlertIds();
      final queuedAlerts = alertRows
          .where((a) => !notifiedIds.contains(a.id))
          .toList();

      if (queuedAlerts.isEmpty) return;

      if (queuedAlerts.length > 3) {
        const summaryTitle = 'Rangkuman Pengingat Keuangan';
        final summaryBody =
            'Kamu memiliki ${queuedAlerts.length} peringatan anggaran baru.';

        await _notifications.show(
          id: 'summary_alert'.hashCode,
          title: summaryTitle,
          body: summaryBody,
          notificationDetails: notificationDetails,
          payload: 'duasaku://alert_center',
        );

        for (final alert in queuedAlerts) {
          await _markAlertAsNotified(alert.id);
        }
      } else {
        for (int i = 0; i < queuedAlerts.length; i++) {
          final alert = queuedAlerts[i];
          const title = 'Peringatan Anggaran';

          await _notifications.show(
            id: _generateNotificationId(alert.id),
            title: title,
            body: alert.message,
            notificationDetails: notificationDetails,
            payload: buildPayload(alert.id),
          );

          await _markAlertAsNotified(alert.id);

          if (i < queuedAlerts.length - 1) {
            await Future.delayed(const Duration(seconds: 10));
          }
        }
      }
    } catch (_) {}
  }
}
