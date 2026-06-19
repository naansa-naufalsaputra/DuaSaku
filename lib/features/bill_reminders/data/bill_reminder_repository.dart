import 'package:drift/drift.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import '../domain/models/bill_reminder_model.dart';
import '../domain/bill_reminder_repository_interface.dart';
import 'dart:developer' as developer;

class BillReminderRepository implements BillReminderRepositoryInterface {
  final AppDatabase _db;

  BillReminderRepository(this._db);

  @override
  Future<Result<List<BillReminderModel>, AppError>> getBillReminders(
    String userId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.billReminders)
                ..where((b) => b.userId.equals(userId))
                ..orderBy([(b) => OrderingTerm.asc(b.dueDate)]))
              .get();

      return Success(rows.map(_mapToModel).toList());
    } catch (e, stack) {
      developer.log('Error fetching bill reminders', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<BillReminderModel?, AppError>> getBillReminderById(
    String reminderId,
  ) async {
    try {
      final row = await (_db.select(
        _db.billReminders,
      )..where((b) => b.id.equals(reminderId))).getSingleOrNull();

      if (row == null) return const Success(null);
      return Success(_mapToModel(row));
    } catch (e, stack) {
      developer.log('Error fetching bill reminder by ID', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> createBillReminder(
    BillReminderModel reminder,
  ) async {
    try {
      await _db
          .into(_db.billReminders)
          .insert(
            BillRemindersCompanion.insert(
              id: reminder.id,
              userId: reminder.userId,
              title: reminder.title,
              amount: reminder.amount,
              currency: Value(reminder.currency),
              dueDate: reminder.dueDate,
              reminderDaysBefore: Value(reminder.reminderDaysBefore),
              status: reminder.status,
              notes: Value(reminder.notes),
              recurringTransactionId: Value(reminder.recurringTransactionId),
              lastReminderSentAt: Value(reminder.lastReminderSentAt),
              createdAt: reminder.createdAt,
            ),
          );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error creating bill reminder', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> updateBillReminder(
    BillReminderModel reminder,
  ) async {
    try {
      await (_db.update(
        _db.billReminders,
      )..where((b) => b.id.equals(reminder.id))).write(
        BillRemindersCompanion(
          title: Value(reminder.title),
          amount: Value(reminder.amount),
          currency: Value(reminder.currency),
          dueDate: Value(reminder.dueDate),
          reminderDaysBefore: Value(reminder.reminderDaysBefore),
          status: Value(reminder.status),
          notes: Value(reminder.notes),
          lastReminderSentAt: Value(reminder.lastReminderSentAt),
        ),
      );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error updating bill reminder', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> deleteBillReminder(String reminderId) async {
    try {
      await (_db.delete(
        _db.billReminders,
      )..where((b) => b.id.equals(reminderId))).go();
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error deleting bill reminder', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Stream<List<BillReminderModel>> watchBillReminders(String userId) {
    return (_db.select(_db.billReminders)
          ..where((b) => b.userId.equals(userId))
          ..orderBy([(b) => OrderingTerm.asc(b.dueDate)]))
        .watch()
        .map((rows) => rows.map(_mapToModel).toList());
  }

  @override
  Stream<List<BillReminderModel>> watchPendingBillReminders(String userId) {
    return (_db.select(_db.billReminders)
          ..where((b) => b.userId.equals(userId) & b.status.equals('pending'))
          ..orderBy([(b) => OrderingTerm.asc(b.dueDate)]))
        .watch()
        .map((rows) => rows.map(_mapToModel).toList());
  }

  BillReminderModel _mapToModel(BillReminder row) {
    return BillReminderModel(
      id: row.id,
      userId: row.userId,
      title: row.title,
      amount: row.amount,
      currency: row.currency,
      dueDate: row.dueDate,
      reminderDaysBefore: row.reminderDaysBefore,
      status: row.status,
      notes: row.notes,
      recurringTransactionId: row.recurringTransactionId,
      lastReminderSentAt: row.lastReminderSentAt,
      createdAt: row.createdAt,
    );
  }
}
