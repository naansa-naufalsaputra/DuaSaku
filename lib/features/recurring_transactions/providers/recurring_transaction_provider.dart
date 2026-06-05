import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/local_db/app_database_provider.dart';
import '../../../core/utils/result.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/recurring_transaction_repository.dart';
import '../domain/models/recurring_status.dart';
import '../domain/models/recurring_transaction_model.dart';
import '../domain/recurring_transaction_repository_interface.dart';
import '../services/recurring_notification_service.dart';

// ─── Notification Service Provider ────────────────────────────────────────────

/// Provides the RecurringNotificationService for scheduling reminders.
final recurringNotificationServiceProvider =
    Provider<RecurringNotificationService>((ref) {
  final plugin = FlutterLocalNotificationsPlugin();
  return RecurringNotificationService(plugin);
});

// ─── Repository Provider ──────────────────────────────────────────────────────

/// Provides the recurring transaction repository (abstract interface type).
final recurringTransactionRepositoryProvider =
    Provider<RecurringTransactionRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RecurringTransactionRepository(db);
});

// ─── Main List Notifier ───────────────────────────────────────────────────────

/// AsyncNotifier managing the full list of recurring transactions with
/// CRUD mutations (create, update, delete, pause, resume).
class RecurringTransactionNotifier
    extends AsyncNotifier<List<RecurringTransactionModel>> {
  @override
  Future<List<RecurringTransactionModel>> build() async {
    final repo = ref.watch(recurringTransactionRepositoryProvider);
    final user = ref.watch(userProvider);
    if (user == null) return [];

    // Use a stream subscription for realtime updates
    final completer = Completer<List<RecurringTransactionModel>>();
    bool isFirst = true;

    final subscription = repo.watchAll(user.id).listen((data) {
      if (isFirst) {
        completer.complete(data);
        isFirst = false;
      } else {
        state = AsyncData(data);
      }
    }, onError: (Object e, StackTrace stack) {
      if (isFirst) {
        completer.completeError(e, stack);
      } else {
        state = AsyncError(e, stack);
      }
    });

    ref.onDispose(() => subscription.cancel());

    return completer.future;
  }

  /// Create a new recurring transaction.
  Future<void> create(RecurringTransactionModel model) async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final result = await repo.create(model);
    switch (result) {
      case Success():
        // Schedule reminder notification if enabled
        await _scheduleReminderIfEnabled(model);
        ref.invalidateSelf();
      case Failure(:final error):
        throw Exception(error.message);
    }
  }

  /// Update an existing recurring transaction template.
  Future<void> updateRecurring(RecurringTransactionModel model) async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final result = await repo.update(model);
    switch (result) {
      case Success():
        // Re-schedule reminder notification (cancel old, schedule new if enabled)
        final notificationService =
            ref.read(recurringNotificationServiceProvider);
        await notificationService.cancelNotifications(model.id);
        await _scheduleReminderIfEnabled(model);
        ref.invalidateSelf();
      case Failure(:final error):
        throw Exception(error.message);
    }
  }

  /// Delete a recurring transaction by ID.
  Future<void> delete(String id) async {
    final repo = ref.read(recurringTransactionRepositoryProvider);

    // Cancel any scheduled notifications before deleting
    final notificationService =
        ref.read(recurringNotificationServiceProvider);
    await notificationService.cancelNotifications(id);

    final result = await repo.delete(id);
    switch (result) {
      case Success():
        ref.invalidateSelf();
      case Failure(:final error):
        throw Exception(error.message);
    }
  }

  /// Pause an active recurring transaction.
  Future<void> pause(String id) async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final result = await repo.updateStatus(id, RecurringStatus.paused);
    switch (result) {
      case Success():
        ref.invalidateSelf();
      case Failure(:final error):
        throw Exception(error.message);
    }
  }

  /// Resume a paused recurring transaction.
  Future<void> resume(String id) async {
    final repo = ref.read(recurringTransactionRepositoryProvider);
    final result = await repo.updateStatus(id, RecurringStatus.active);
    switch (result) {
      case Success():
        ref.invalidateSelf();
      case Failure(:final error):
        throw Exception(error.message);
    }
  }

  /// Schedule a reminder notification if the model has notifyBefore enabled.
  Future<void> _scheduleReminderIfEnabled(
    RecurringTransactionModel model,
  ) async {
    if (!model.notifyBefore) return;

    try {
      final notificationService =
          ref.read(recurringNotificationServiceProvider);
      final transactionName = model.notes ?? 'Recurring Transaction';

      await notificationService.scheduleReminder(
        recurringTransactionId: model.id,
        transactionName: transactionName,
        executionDate: model.nextExecutionDate,
        timing: model.reminderTiming,
      );
    } catch (e) {
      // Notification scheduling failure should not block create/update
      // The transaction is still saved successfully.
    }
  }
}

final recurringTransactionNotifierProvider = AsyncNotifierProvider<
    RecurringTransactionNotifier, List<RecurringTransactionModel>>(() {
  return RecurringTransactionNotifier();
});

// ─── Dashboard Upcoming Provider ──────────────────────────────────────────────

/// Provides up to 5 upcoming recurring transactions within 7 days
/// for the dashboard widget. Auto-disposes when no longer watched.
final upcomingRecurringProvider =
    FutureProvider.autoDispose<List<RecurringTransactionModel>>((ref) async {
  final repo = ref.watch(recurringTransactionRepositoryProvider);
  final user = ref.watch(userProvider);
  if (user == null) return [];
  return repo.getUpcoming(user.id, 7, 5);
});

// ─── Single Recurring Transaction by ID ───────────────────────────────────────

/// Provides a single recurring transaction by ID for the detail view.
/// Returns null if not found. Auto-disposes when no longer watched.
final recurringTransactionByIdProvider = FutureProvider.autoDispose
    .family<RecurringTransactionModel?, String>((ref, id) async {
  final repo = ref.watch(recurringTransactionRepositoryProvider);
  final result = await repo.getById(id);
  return switch (result) {
    Success(:final value) => value,
    Failure() => null,
  };
});
