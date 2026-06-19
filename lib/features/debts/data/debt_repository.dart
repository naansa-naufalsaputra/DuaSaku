import 'package:drift/drift.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import '../domain/models/debt_model.dart';
import '../domain/debt_repository_interface.dart';
import 'dart:developer' as developer;

class DebtRepository implements DebtRepositoryInterface {
  final AppDatabase _db;

  DebtRepository(this._db);

  @override
  Future<Result<List<DebtModel>, AppError>> getDebts(String userId) async {
    try {
      final rows =
          await (_db.select(_db.debts)
                ..where((d) => d.userId.equals(userId))
                ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
              .get();

      return Success(rows.map(_mapToModel).toList());
    } catch (e, stack) {
      developer.log('Error fetching debts', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<DebtModel?, AppError>> getDebtById(String debtId) async {
    try {
      final row = await (_db.select(
        _db.debts,
      )..where((d) => d.id.equals(debtId))).getSingleOrNull();

      if (row == null) return const Success(null);
      return Success(_mapToModel(row));
    } catch (e, stack) {
      developer.log('Error fetching debt by ID', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<DebtModel>, AppError>> getDebtsByStatus(
    String userId,
    String status,
  ) async {
    try {
      final rows =
          await (_db.select(_db.debts)
                ..where(
                  (d) => d.userId.equals(userId) & d.status.equals(status),
                )
                ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
              .get();

      return Success(rows.map(_mapToModel).toList());
    } catch (e, stack) {
      developer.log('Error fetching debts by status', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<DebtModel>, AppError>> getOverdueDebts(
    String userId,
  ) async {
    try {
      final now = DateTime.now();
      final rows =
          await (_db.select(_db.debts)
                ..where(
                  (d) =>
                      d.userId.equals(userId) &
                      d.status.isNotValue('paid') &
                      d.dueDate.isSmallerThanValue(now),
                )
                ..orderBy([(d) => OrderingTerm.asc(d.dueDate)]))
              .get();

      return Success(rows.map(_mapToModel).toList());
    } catch (e, stack) {
      developer.log('Error fetching overdue debts', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> createDebt(DebtModel debt) async {
    try {
      await _db
          .into(_db.debts)
          .insert(
            DebtsCompanion.insert(
              id: debt.id,
              userId: debt.userId,
              type: debt.type,
              personName: debt.personName,
              amount: debt.amount,
              currency: Value(debt.currency),
              paidAmount: Value(debt.paidAmount),
              status: debt.status,
              notes: Value(debt.notes),
              dueDate: Value(debt.dueDate),
              createdAt: debt.createdAt,
              settledAt: Value(debt.settledAt),
            ),
          );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error creating debt', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> updateDebt(DebtModel debt) async {
    try {
      await (_db.update(_db.debts)..where((d) => d.id.equals(debt.id))).write(
        DebtsCompanion(
          personName: Value(debt.personName),
          amount: Value(debt.amount),
          currency: Value(debt.currency),
          paidAmount: Value(debt.paidAmount),
          status: Value(debt.status),
          notes: Value(debt.notes),
          dueDate: Value(debt.dueDate),
          settledAt: Value(debt.settledAt),
        ),
      );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error updating debt', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> deleteDebt(String debtId) async {
    try {
      await (_db.delete(_db.debts)..where((d) => d.id.equals(debtId))).go();
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error deleting debt', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> addPayment(
    String debtId,
    DebtPaymentModel payment,
  ) async {
    try {
      await _db.transaction(() async {
        // 1. Insert payment record
        await _db
            .into(_db.debtPayments)
            .insert(
              DebtPaymentsCompanion.insert(
                id: payment.id,
                debtId: payment.debtId,
                amount: payment.amount,
                notes: Value(payment.notes),
                paidAt: payment.paidAt,
              ),
            );

        // 2. Update debt paid_amount and status
        final debt = await (_db.select(
          _db.debts,
        )..where((d) => d.id.equals(debtId))).getSingle();

        final newPaidAmount = debt.paidAmount + payment.amount;
        final newStatus = newPaidAmount >= debt.amount ? 'paid' : 'partial';

        await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
          DebtsCompanion(
            paidAmount: Value(newPaidAmount),
            status: Value(newStatus),
            settledAt: Value(newStatus == 'paid' ? DateTime.now() : null),
          ),
        );
      });

      return const Success(null);
    } catch (e, stack) {
      developer.log('Error adding payment', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<List<DebtPaymentModel>, AppError>> getPaymentHistory(
    String debtId,
  ) async {
    try {
      final rows =
          await (_db.select(_db.debtPayments)
                ..where((p) => p.debtId.equals(debtId))
                ..orderBy([(p) => OrderingTerm.desc(p.paidAt)]))
              .get();

      return Success(
        rows
            .map(
              (p) => DebtPaymentModel(
                id: p.id,
                debtId: p.debtId,
                amount: p.amount,
                notes: p.notes,
                paidAt: p.paidAt,
              ),
            )
            .toList(),
      );
    } catch (e, stack) {
      developer.log('Error fetching payment history', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Stream<List<DebtModel>> watchDebts(String userId) {
    return (_db.select(_db.debts)
          ..where((d) => d.userId.equals(userId))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch()
        .map((rows) => rows.map(_mapToModel).toList());
  }

  @override
  Stream<List<DebtModel>> watchDebtsByStatus(String userId, String status) {
    return (_db.select(_db.debts)
          ..where((d) => d.userId.equals(userId) & d.status.equals(status))
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .watch()
        .map((rows) => rows.map(_mapToModel).toList());
  }

  DebtModel _mapToModel(Debt row) {
    return DebtModel(
      id: row.id,
      userId: row.userId,
      type: row.type,
      personName: row.personName,
      amount: row.amount,
      currency: row.currency,
      paidAmount: row.paidAmount,
      status: row.status,
      notes: row.notes,
      dueDate: row.dueDate,
      createdAt: row.createdAt,
      settledAt: row.settledAt,
    );
  }
}
