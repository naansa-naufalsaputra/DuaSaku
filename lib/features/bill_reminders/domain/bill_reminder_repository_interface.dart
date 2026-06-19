import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/bill_reminder_model.dart';

abstract class BillReminderRepositoryInterface {
  Future<Result<List<BillReminderModel>, AppError>> getBillReminders(
    String userId,
  );
  Future<Result<BillReminderModel?, AppError>> getBillReminderById(
    String reminderId,
  );
  Future<Result<void, AppError>> createBillReminder(BillReminderModel reminder);
  Future<Result<void, AppError>> updateBillReminder(BillReminderModel reminder);
  Future<Result<void, AppError>> deleteBillReminder(String reminderId);
  Stream<List<BillReminderModel>> watchBillReminders(String userId);
  Stream<List<BillReminderModel>> watchPendingBillReminders(String userId);
}
