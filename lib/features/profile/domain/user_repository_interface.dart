import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import 'models/user_model.dart';

abstract class UserRepositoryInterface {
  /// Get all users (profiles)
  Future<Result<List<UserModel>, AppError>> getAllUsers();

  /// Get user by ID
  Future<Result<UserModel?, AppError>> getUserById(String userId);

  /// Create new user profile
  Future<Result<void, AppError>> createUser(UserModel user);

  /// Update user profile
  Future<Result<void, AppError>> updateUser(UserModel user);

  /// Delete user profile (and all associated data)
  Future<Result<void, AppError>> deleteUser(String userId);

  /// Update last active timestamp
  Future<Result<void, AppError>> updateLastActive(String userId);

  /// Watch all users (reactive stream)
  Stream<List<UserModel>> watchAllUsers();
}
