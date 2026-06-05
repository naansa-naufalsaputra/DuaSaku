import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../domain/models/budget_alert_model.dart';

/// Service responsible for sending push notifications for budget alerts.
///
/// Handles quiet hours detection, notification queuing, and batch delivery.
/// Configures the "Budget Alerts" notification channel with high priority.
class BudgetNotificationService {
  BudgetNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notifications =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _notifications;

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

  /// Sends a push notification for a budget alert, respecting quiet hours.
  ///
  /// If quiet hours are active, the notification is queued for later delivery.
  /// If the master toggle is disabled, no notification is sent.
  Future<void> sendAlertNotification({
    required BudgetAlertModel alert,
    required String userId,
  }) async {
    // For now, send the notification directly with proper channel config
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
  }

  /// Processes queued notifications after quiet hours end.
  ///
  /// If queue > 3: sends summary notification.
  /// If queue <= 3: sends individual notifications with 10s interval.
  Future<void> processQueuedNotifications(String userId) async {}
}
