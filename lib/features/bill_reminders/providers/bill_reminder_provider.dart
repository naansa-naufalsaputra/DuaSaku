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
import '../data/bill_reminder_repository.dart';
import '../domain/bill_reminder_repository_interface.dart';
import '../domain/models/bill_reminder_model.dart';

const _uuid = Uuid();

final billReminderRepositoryProvider = Provider<BillReminderRepositoryInterface>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BillReminderRepository(db);
});

final billReminderNotifierProvider =
    AsyncNotifierProvider<BillReminderNotifier, List<BillReminderModel>>(BillReminderNotifier.new);

class BillReminderNotifier extends AsyncNotifier<List<BillReminderModel>> {
  late BillReminderRepositoryInterface _repository;
  StreamSubscription<List<BillReminderModel>>? _subscription;

  @override
  Future<List<BillReminderModel>> build() async {
    _repository = ref.watch(billReminderRepositoryProvider);
    final user = ref.watch(userProvider);

    _subscription?.cancel();
    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (user?.id == null) {
      return [];
    }

    final completer = Completer<List<BillReminderModel>>();
    bool isFirst = true;

    _subscription = _repository.watchBillReminders(user!.id).listen(
      (reminders) {
        if (isFirst) {
          completer.complete(reminders);
          isFirst = false;
        } else {
          state = AsyncData(reminders);
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

  Future<Result<void, AppError>> createBillReminder({
    required String title,
    required double amount,
    required DateTime dueDate,
    int reminderDaysBefore = 7,
    String? notes,
    String? recurringTransactionId,
  }) async {
    final user = ref.read(userProvider);
    if (user?.id == null) {
      return Failure(AppError.validation('User not authenticated'));
    }

    if (title.trim().isEmpty) {
      return Failure(AppError.validation('Title cannot be empty'));
    }

    if (amount <= 0) {
      return Failure(AppError.validation('Amount must be greater than zero'));
    }

    final reminder = BillReminderModel(
      id: _uuid.v4(),
      userId: user!.id,
      title: title.trim(),
      amount: amount,
      currency: 'IDR',
      dueDate: dueDate,
      reminderDaysBefore: reminderDaysBefore,
      status: 'pending',
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      recurringTransactionId: recurringTransactionId,
      createdAt: DateTime.now(),
    );

    return _repository.createBillReminder(reminder);
  }

  Future<Result<void, AppError>> updateBillReminder(BillReminderModel reminder) async {
    if (reminder.title.trim().isEmpty) {
      return Failure(AppError.validation('Title cannot be empty'));
    }
    if (reminder.amount <= 0) {
      return Failure(AppError.validation('Amount must be greater than zero'));
    }
    return _repository.updateBillReminder(reminder);
  }

  Future<Result<void, AppError>> deleteBillReminder(String reminderId) async {
    return _repository.deleteBillReminder(reminderId);
  }

  Future<Result<void, AppError>> markAsPaid({
    required String reminderId,
    required String walletId,
    bool deductWallet = true,
  }) async {
    final reminderResult = await _repository.getBillReminderById(reminderId);
    if (reminderResult is Failure) {
      return Failure((reminderResult as Failure).error as AppError);
    }

    final reminder = (reminderResult as Success<BillReminderModel?, AppError>).value;
    if (reminder == null) {
      return Failure(AppError.validation('Bill reminder not found'));
    }

    final updatedReminder = reminder.copyWith(status: 'paid');
    final updateResult = await _repository.updateBillReminder(updatedReminder);
    if (updateResult is Failure) {
      return updateResult;
    }

    if (deductWallet) {
      final user = ref.read(userProvider);
      if (user?.id == null) {
        return Failure(AppError.validation('User not authenticated'));
      }

      final txNotes = 'Pembayaran tagihan: ${reminder.title}. ${reminder.notes ?? ''}';
      
      final transaction = TransactionModel(
        userId: user!.id,
        amount: reminder.amount,
        categoryId: 'bills', // default to bills category
        notes: txNotes.trim(),
        createdAt: DateTime.now(),
        type: 'expense',
        walletId: walletId,
      );

      await ref.read(transactionNotifierProvider.notifier).addTransaction(transaction);
    }

    return const Success(null);
  }
}
