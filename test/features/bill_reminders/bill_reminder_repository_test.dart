import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/bill_reminders/data/bill_reminder_repository.dart';
import 'package:duasaku_app/features/bill_reminders/domain/models/bill_reminder_model.dart';
import 'package:duasaku_app/core/utils/result.dart';

AppDatabase _createTestDb() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(
      setup: (db) {
        db.execute('PRAGMA foreign_keys = ON;');
      },
    ),
  );
}

void main() {
  late AppDatabase db;
  late BillReminderRepository repository;

  setUp(() {
    db = _createTestDb();
    repository = BillReminderRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BillReminderRepository Tests', () {
    final testReminder = BillReminderModel(
      id: 'reminder-1',
      userId: 'user-1',
      title: 'Electricity Bill',
      amount: 150000,
      dueDate: DateTime.now().add(const Duration(days: 5)),
      reminderDaysBefore: 7,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    test('createBillReminder and getBillReminders', () async {
      final createRes = await repository.createBillReminder(testReminder);
      expect(createRes, isA<Success<void, dynamic>>());

      final getRes = await repository.getBillReminders('user-1');
      expect(getRes, isA<Success<List<BillReminderModel>, dynamic>>());

      final list = (getRes as Success<List<BillReminderModel>, dynamic>).value;
      expect(list.length, equals(1));
      expect(list.first.title, equals('Electricity Bill'));
      expect(list.first.amount, equals(150000));
      expect(list.first.reminderDaysBefore, equals(7));
    });

    test('getBillReminderById returns correct reminder', () async {
      await repository.createBillReminder(testReminder);

      final res = await repository.getBillReminderById('reminder-1');
      expect(res, isA<Success<BillReminderModel?, dynamic>>());

      final reminder = (res as Success<BillReminderModel?, dynamic>).value;
      expect(reminder, isNotNull);
      expect(reminder!.id, equals('reminder-1'));
    });

    test('updateBillReminder modifies details', () async {
      await repository.createBillReminder(testReminder);

      final updated = testReminder.copyWith(
        title: 'Water Bill',
        amount: 50000,
        status: 'paid',
      );

      final updateRes = await repository.updateBillReminder(updated);
      expect(updateRes, isA<Success<void, dynamic>>());

      final res = await repository.getBillReminderById('reminder-1');
      final reminder = (res as Success<BillReminderModel?, dynamic>).value!;
      expect(reminder.title, equals('Water Bill'));
      expect(reminder.amount, equals(50000));
      expect(reminder.status, equals('paid'));
    });

    test('deleteBillReminder removes it', () async {
      await repository.createBillReminder(testReminder);

      final delRes = await repository.deleteBillReminder('reminder-1');
      expect(delRes, isA<Success<void, dynamic>>());

      final getRes = await repository.getBillReminderById('reminder-1');
      expect((getRes as Success<BillReminderModel?, dynamic>).value, isNull);
    });
  });
}
