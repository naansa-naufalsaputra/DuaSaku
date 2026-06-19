import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/local_db/app_database_provider.dart';
import '../../../core/utils/app_error.dart';
import '../../../core/utils/result.dart';
import '../../auth/providers/auth_provider.dart';
import '../../wallets/providers/wallet_provider.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/domain/models/transaction_model.dart';
import '../data/debt_repository.dart';
import '../domain/debt_repository_interface.dart';
import '../domain/models/debt_model.dart';

const _uuid = Uuid();

final debtRepositoryProvider = Provider<DebtRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DebtRepository(db);
});

final debtNotifierProvider =
    AsyncNotifierProvider<DebtNotifier, List<DebtModel>>(DebtNotifier.new);

final debtPaymentHistoryProvider =
    FutureProvider.family<List<DebtPaymentModel>, String>((ref, debtId) async {
      final repo = ref.watch(debtRepositoryProvider);
      final result = await repo.getPaymentHistory(debtId);
      switch (result) {
        case Success(:final value):
          return value;
        case Failure():
          return [];
      }
    });

class DebtNotifier extends AsyncNotifier<List<DebtModel>> {
  late DebtRepositoryInterface _repository;
  StreamSubscription<List<DebtModel>>? _subscription;

  @override
  Future<List<DebtModel>> build() async {
    _repository = ref.watch(debtRepositoryProvider);
    final user = ref.watch(userProvider);

    _subscription?.cancel();
    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (user?.id == null) {
      return [];
    }

    final completer = Completer<List<DebtModel>>();
    bool isFirst = true;

    _subscription = _repository
        .watchDebts(user!.id)
        .listen(
          (debts) {
            if (isFirst) {
              completer.complete(debts);
              isFirst = false;
            } else {
              state = AsyncData(debts);
            }
          },
          onError: (e, stack) {
            if (isFirst) {
              completer.completeError(e, stack);
              isFirst = false;
            } else {
              state = AsyncError(e, stack);
            }
          },
        );

    return completer.future;
  }

  Future<Result<void, AppError>> createDebt({
    required String type,
    required String personName,
    required double amount,
    String currency = 'IDR',
    String? notes,
    DateTime? dueDate,
  }) async {
    final user = ref.read(userProvider);
    if (user?.id == null) {
      return Failure(AppError.validation('User not authenticated'));
    }

    if (personName.trim().isEmpty) {
      return Failure(AppError.validation('Person name cannot be empty'));
    }

    if (amount <= 0) {
      return Failure(AppError.validation('Amount must be greater than zero'));
    }

    final debt = DebtModel(
      id: _uuid.v4(),
      userId: user!.id,
      type: type,
      personName: personName.trim(),
      amount: amount,
      currency: currency,
      paidAmount: 0.0,
      status: 'unpaid',
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );

    return _repository.createDebt(debt);
  }

  Future<Result<void, AppError>> addPayment({
    required String debtId,
    required double amount,
    required String walletId,
    String? notes,
    bool deductWallet = true,
  }) async {
    if (amount <= 0) {
      return Failure(
        AppError.validation('Payment amount must be greater than zero'),
      );
    }

    final debtResult = await _repository.getDebtById(debtId);
    if (debtResult is Failure) {
      return Failure((debtResult as Failure).error as AppError);
    }

    final debt = (debtResult as Success<DebtModel?, AppError>).value;
    if (debt == null) {
      return Failure(AppError.validation('Debt not found'));
    }

    if (debt.isSettled) {
      return Failure(AppError.validation('Debt is already fully settled'));
    }

    final remaining = debt.remainingAmount;
    final paymentAmount = amount > remaining ? remaining : amount;

    final payment = DebtPaymentModel(
      id: _uuid.v4(),
      debtId: debtId,
      amount: paymentAmount,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      paidAt: DateTime.now(),
    );

    // 1. Add payment to debt (handles DB transaction for debt payments and debt status/paidAmount update)
    final paymentResult = await _repository.addPayment(debtId, payment);
    if (paymentResult is Failure) {
      return paymentResult;
    }

    // 2. If deductWallet is selected, add transaction record which updates the wallet balance
    if (deductWallet) {
      final user = ref.read(userProvider);
      if (user?.id == null) {
        return Failure(AppError.validation('User not authenticated'));
      }

      final transactionType = debt.type == 'debt' ? 'expense' : 'income';
      final categoryId = debt.type == 'debt' ? 'bills' : 'salary';
      final txNotes =
          'Pembayaran ${debt.type == 'debt' ? 'utang' : 'piutang'} kepada/dari ${debt.personName}. ${notes ?? ''}';

      final transaction = TransactionModel(
        userId: user!.id,
        amount: paymentAmount,
        categoryId: categoryId,
        notes: txNotes.trim(),
        createdAt: DateTime.now(),
        type: transactionType,
        walletId: walletId,
      );

      await ref
          .read(transactionNotifierProvider.notifier)
          .addTransaction(transaction);
    }

    return const Success(null);
  }

  Future<Result<void, AppError>> deleteDebt(String debtId) async {
    return _repository.deleteDebt(debtId);
  }

  Future<Result<List<DebtPaymentModel>, AppError>> getPaymentHistory(
    String debtId,
  ) async {
    return _repository.getPaymentHistory(debtId);
  }
}
