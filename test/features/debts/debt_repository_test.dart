import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/features/debts/data/debt_repository.dart';
import 'package:duasaku_app/features/debts/domain/models/debt_model.dart';
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
  late DebtRepository repository;

  setUp(() {
    db = _createTestDb();
    repository = DebtRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DebtRepository Tests', () {
    final testDebt = DebtModel(
      id: 'debt-1',
      userId: 'user-1',
      type: 'debt',
      personName: 'John Doe',
      amount: 100000,
      currency: 'IDR',
      paidAmount: 0,
      status: 'unpaid',
      createdAt: DateTime.now(),
    );

    test('createDebt and getDebts', () async {
      final createRes = await repository.createDebt(testDebt);
      expect(createRes, isA<Success<void, dynamic>>());

      final getRes = await repository.getDebts('user-1');
      expect(getRes, isA<Success<List<DebtModel>, dynamic>>());
      
      final list = (getRes as Success<List<DebtModel>, dynamic>).value;
      expect(list.length, equals(1));
      expect(list.first.personName, equals('John Doe'));
      expect(list.first.amount, equals(100000));
    });

    test('getDebtById returns correct debt', () async {
      await repository.createDebt(testDebt);

      final res = await repository.getDebtById('debt-1');
      expect(res, isA<Success<DebtModel?, dynamic>>());
      
      final debt = (res as Success<DebtModel?, dynamic>).value;
      expect(debt, isNotNull);
      expect(debt!.id, equals('debt-1'));
    });

    test('addPayment updates debt status and paidAmount', () async {
      await repository.createDebt(testDebt);

      final payment = DebtPaymentModel(
        id: 'pay-1',
        debtId: 'debt-1',
        amount: 40000,
        paidAt: DateTime.now(),
      );

      final payRes = await repository.addPayment('debt-1', payment);
      expect(payRes, isA<Success<void, dynamic>>());

      final getRes = await repository.getDebtById('debt-1');
      final debt = (getRes as Success<DebtModel?, dynamic>).value!;
      expect(debt.paidAmount, equals(40000));
      expect(debt.status, equals('partial'));

      // Complete payment
      final payment2 = DebtPaymentModel(
        id: 'pay-2',
        debtId: 'debt-1',
        amount: 60000,
        paidAt: DateTime.now(),
      );
      await repository.addPayment('debt-1', payment2);

      final getRes2 = await repository.getDebtById('debt-1');
      final debt2 = (getRes2 as Success<DebtModel?, dynamic>).value!;
      expect(debt2.paidAmount, equals(100000));
      expect(debt2.status, equals('paid'));
      expect(debt2.settledAt, isNotNull);
    });

    test('deleteDebt removes the debt', () async {
      await repository.createDebt(testDebt);
      
      final delRes = await repository.deleteDebt('debt-1');
      expect(delRes, isA<Success<void, dynamic>>());

      final getRes = await repository.getDebtById('debt-1');
      expect((getRes as Success<DebtModel?, dynamic>).value, isNull);
    });
  });
}
