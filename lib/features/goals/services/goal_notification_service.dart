import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/goal_model.dart';

/// Handles all notifications related to financial goals.
///
/// Responsibilities:
/// - Send immediate milestone notifications (25%, 50%, 75%)
/// - Send immediate completion celebration notification
/// - Schedule deadline reminders (7 days and 1 day before)
/// - Cancel all notifications for a goal on deletion
///
/// Uses flutter_local_notifications with deep link payload for navigation.
class GoalNotificationService {
  final FlutterLocalNotificationsPlugin _notifications;

  /// Android notification channel for financial goals.
  static const String _channelId = 'financial_goals';
  static const String _channelName = 'Financial Goals';
  static const String _channelDescription =
      'Notifications for goal milestones, completion, and deadline reminders';

  GoalNotificationService(this._notifications);

  /// Send an immediate notification when a milestone is reached.
  ///
  /// Milestones are 25%, 50%, 75%. The caller (GoalNotifier) is responsible
  /// for checking `notifiedMilestones` before calling this, but this service
  /// is defensive and will still send the notification regardless.
  Future<void> notifyMilestone(GoalModel goal, int milestonePercent) async {
    final notificationId = _generateNotificationId(goal.id, 'milestone_$milestonePercent');

    final payload = _buildPayload(goal.id);

    final emoji = _milestoneEmoji(milestonePercent);

    await _notifications.show(
      id: notificationId,
      title: '$emoji ${goal.name} - $milestonePercent% tercapai!',
      body: 'Kamu sudah mencapai $milestonePercent% dari target tabungan "${goal.name}". Terus semangat!',
      notificationDetails: _buildNotificationDetails(),
      payload: payload,
    );
  }

  /// Schedule deadline reminder notifications (7 days and 1 day before).
  ///
  /// Only schedules if the goal has a deadline. Skips scheduling if the
  /// reminder time is already in the past.
  Future<void> scheduleDeadlineReminders(GoalModel goal) async {
    if (goal.deadline == null) return;

    final deadline = goal.deadline!;

    // Schedule 7-day reminder (only if goal < 75% complete)
    if (goal.progressPercentage < 0.75) {
      final sevenDaysBefore = deadline.subtract(const Duration(days: 7));
      final scheduledDate7 = tz.TZDateTime(
        tz.local,
        sevenDaysBefore.year,
        sevenDaysBefore.month,
        sevenDaysBefore.day,
        9, // 09:00
        0,
      );

      if (scheduledDate7.isAfter(tz.TZDateTime.now(tz.local))) {
        final notificationId = _generateNotificationId(goal.id, 'deadline_7d');
        final payload = _buildPayload(goal.id);

        await _notifications.zonedSchedule(
          id: notificationId,
          title: '⏰ ${goal.name} - 7 hari lagi!',
          body:
              'Deadline tabungan "${goal.name}" tinggal 7 hari lagi. Progres saat ini ${(goal.progressPercentage * 100).toInt()}%.',
          scheduledDate: scheduledDate7,
          notificationDetails: _buildNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
    }

    // Schedule 1-day reminder (only if goal not complete)
    if (!goal.isCompleted) {
      final oneDayBefore = deadline.subtract(const Duration(days: 1));
      final scheduledDate1 = tz.TZDateTime(
        tz.local,
        oneDayBefore.year,
        oneDayBefore.month,
        oneDayBefore.day,
        9, // 09:00
        0,
      );

      if (scheduledDate1.isAfter(tz.TZDateTime.now(tz.local))) {
        final notificationId = _generateNotificationId(goal.id, 'deadline_1d');
        final payload = _buildPayload(goal.id);

        await _notifications.zonedSchedule(
          id: notificationId,
          title: '🚨 ${goal.name} - Besok deadline!',
          body:
              'Deadline tabungan "${goal.name}" besok! Progres saat ini ${(goal.progressPercentage * 100).toInt()}%. Ayo tambah tabunganmu!',
          scheduledDate: scheduledDate1,
          notificationDetails: _buildNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
      }
    }
  }

  /// Cancel all scheduled notifications for a goal.
  ///
  /// Cancels milestone, deadline, and completion notifications.
  Future<void> cancelGoalNotifications(String goalId) async {
    final notificationIds = [
      _generateNotificationId(goalId, 'milestone_25'),
      _generateNotificationId(goalId, 'milestone_50'),
      _generateNotificationId(goalId, 'milestone_75'),
      _generateNotificationId(goalId, 'deadline_7d'),
      _generateNotificationId(goalId, 'deadline_1d'),
      _generateNotificationId(goalId, 'completion'),
    ];

    await Future.wait(
      notificationIds.map((id) => _notifications.cancel(id: id)),
    );
  }

  /// Send an immediate celebration notification when a goal is completed.
  Future<void> notifyCompletion(GoalModel goal) async {
    final notificationId = _generateNotificationId(goal.id, 'completion');
    final payload = _buildPayload(goal.id);

    await _notifications.show(
      id: notificationId,
      title: '🎉 Selamat! ${goal.name} tercapai!',
      body:
          'Kamu berhasil mencapai target tabungan "${goal.name}"! Luar biasa! 🏆',
      notificationDetails: _buildNotificationDetails(),
      payload: payload,
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Build the deep link payload for notification tap handling.
  String _buildPayload(String goalId) {
    return 'duasaku://goals?id=$goalId';
  }

  /// Generate a unique notification ID from the goal ID and a suffix.
  int _generateNotificationId(String goalId, String suffix) {
    return '${goalId}_$suffix'.hashCode;
  }

  /// Build Android/iOS notification details with the goals channel.
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

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Get an appropriate emoji for the milestone percentage.
  String _milestoneEmoji(int percent) {
    switch (percent) {
      case 25:
        return '🌱';
      case 50:
        return '⭐';
      case 75:
        return '🔥';
      default:
        return '🎯';
    }
  }
}
