import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/reminder_timing.dart';

/// Handles all notifications related to recurring transactions.
///
/// Responsibilities:
/// - Schedule reminder notifications before execution
/// - Show immediate notifications for execution success/failure
/// - Cancel notifications when a recurring transaction is deleted
///
/// Uses flutter_local_notifications with deep link payload for navigation.
class RecurringNotificationService {
  final FlutterLocalNotificationsPlugin _notifications;

  /// Android notification channel for recurring transactions.
  static const String _channelId = 'recurring_transactions';
  static const String _channelName = 'Recurring Transactions';
  static const String _channelDescription =
      'Notifications for recurring transaction reminders and execution results';

  RecurringNotificationService(this._notifications);

  /// Schedule a reminder notification before execution.
  ///
  /// - [ReminderTiming.dayBefore]: schedules at 09:00 the day before execution
  /// - [ReminderTiming.sameDay]: schedules at 08:00 on the execution day
  Future<void> scheduleReminder({
    required String recurringTransactionId,
    required String transactionName,
    required DateTime executionDate,
    required ReminderTiming timing,
  }) async {
    final scheduledDate = _computeReminderDate(executionDate, timing);

    // Don't schedule if the reminder time is already in the past.
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final notificationId = _generateNotificationId(
      recurringTransactionId,
      'reminder',
    );

    final payload = _buildPayload(recurringTransactionId);

    final timingLabel = timing == ReminderTiming.dayBefore
        ? 'besok'
        : 'hari ini';

    await _notifications.zonedSchedule(
      id: notificationId,
      title: '🔔 Reminder: $transactionName',
      body:
          'Transaksi berulang "$transactionName" akan dieksekusi $timingLabel.',
      scheduledDate: scheduledDate,
      notificationDetails: _buildNotificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Show immediate notification after successful execution.
  Future<void> showExecutionSuccess({
    required String recurringTransactionId,
    required String transactionName,
    required double amount,
    required String walletName,
  }) async {
    final notificationId = _generateNotificationId(
      recurringTransactionId,
      'success',
    );

    final payload = _buildPayload(recurringTransactionId);

    await _notifications.show(
      id: notificationId,
      title: '✅ $transactionName berhasil',
      body:
          'Rp ${_formatAmount(amount)} telah dicatat ke wallet "$walletName".',
      notificationDetails: _buildNotificationDetails(),
      payload: payload,
    );
  }

  /// Show immediate notification after failed execution.
  Future<void> showExecutionFailure({
    required String recurringTransactionId,
    required String transactionName,
    required String errorCategory,
  }) async {
    final notificationId = _generateNotificationId(
      recurringTransactionId,
      'failure',
    );

    final payload = _buildPayload(recurringTransactionId);

    await _notifications.show(
      id: notificationId,
      title: '❌ $transactionName gagal',
      body: 'Eksekusi gagal: $errorCategory. Buka app untuk detail.',
      notificationDetails: _buildNotificationDetails(),
      payload: payload,
    );
  }

  /// Cancel all notifications for a recurring transaction.
  ///
  /// Cancels reminder, success, and failure notification IDs.
  Future<void> cancelNotifications(String recurringTransactionId) async {
    final reminderNotifId = _generateNotificationId(
      recurringTransactionId,
      'reminder',
    );
    final successNotifId = _generateNotificationId(
      recurringTransactionId,
      'success',
    );
    final failureNotifId = _generateNotificationId(
      recurringTransactionId,
      'failure',
    );

    await Future.wait([
      _notifications.cancel(id: reminderNotifId),
      _notifications.cancel(id: successNotifId),
      _notifications.cancel(id: failureNotifId),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Compute the scheduled [tz.TZDateTime] for the reminder notification.
  tz.TZDateTime _computeReminderDate(
    DateTime executionDate,
    ReminderTiming timing,
  ) {
    switch (timing) {
      case ReminderTiming.dayBefore:
        final dayBefore = executionDate.subtract(const Duration(days: 1));
        return tz.TZDateTime(
          tz.local,
          dayBefore.year,
          dayBefore.month,
          dayBefore.day,
          9, // 09:00
          0,
        );
      case ReminderTiming.sameDay:
        return tz.TZDateTime(
          tz.local,
          executionDate.year,
          executionDate.month,
          executionDate.day,
          8, // 08:00
          0,
        );
    }
  }

  /// Build the deep link payload for notification tap handling.
  String _buildPayload(String recurringTransactionId) {
    return 'duasaku://recurring_transactions?id=$recurringTransactionId';
  }

  /// Generate a unique notification ID from the recurring transaction ID and
  /// a suffix to differentiate reminder/success/failure notifications.
  int _generateNotificationId(String recurringTransactionId, String suffix) {
    return '${recurringTransactionId}_$suffix'.hashCode;
  }

  /// Build Android/iOS notification details with the recurring channel.
  NotificationDetails _buildNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Format amount for display in notification body.
  String _formatAmount(double amount) {
    // Simple formatting: add thousand separators
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
    }
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return '$intPart,${parts[1]}';
  }
}
