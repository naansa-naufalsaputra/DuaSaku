import '../../../core/utils/result.dart';
import '../../../core/utils/app_error.dart';
import 'models/wallet_model.dart';

/// Abstract interface for wallet repository operations.
/// Concrete implementations handle the actual data source (Drift, API, etc.).
///
/// Methods that can fail with expected errors (DB constraint violations,
/// not-found) return [Result<T, AppError>] instead of throwing exceptions.
abstract class WalletRepositoryInterface {
  Future<Result<List<WalletModel>, AppError>> getWallets(String userId);
  Stream<List<WalletModel>> watchWallets(String userId);
  Future<Result<void, AppError>> createWallet(WalletModel wallet);
  Future<Result<void, AppError>> updateWallet(WalletModel wallet);
  Future<Result<void, AppError>> deleteWallet(String walletId);
}
