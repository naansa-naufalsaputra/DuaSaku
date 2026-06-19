import 'package:drift/drift.dart';
import 'package:duasaku_app/core/local_db/app_database.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/core/utils/app_error.dart';
import '../domain/models/user_model.dart';
import '../domain/user_repository_interface.dart';
import 'dart:developer' as developer;

class UserRepository implements UserRepositoryInterface {
  final AppDatabase _db;

  UserRepository(this._db);

  @override
  Future<Result<List<UserModel>, AppError>> getAllUsers() async {
    try {
      final rows = await _db.select(_db.users).get();
      return Success(
        rows
            .map(
              (u) => UserModel(
                id: u.id,
                name: u.name,
                email: u.email,
                avatarPath: u.avatarPath,
                createdAt: u.createdAt,
                lastActiveAt: u.lastActiveAt,
              ),
            )
            .toList(),
      );
    } catch (e, stack) {
      developer.log('Error fetching users from Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<UserModel?, AppError>> getUserById(String userId) async {
    try {
      final row = await (_db.select(
        _db.users,
      )..where((u) => u.id.equals(userId))).getSingleOrNull();

      if (row == null) return const Success(null);

      return Success(
        UserModel(
          id: row.id,
          name: row.name,
          email: row.email,
          avatarPath: row.avatarPath,
          createdAt: row.createdAt,
          lastActiveAt: row.lastActiveAt,
        ),
      );
    } catch (e, stack) {
      developer.log('Error fetching user by ID', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> createUser(UserModel user) async {
    try {
      await _db
          .into(_db.users)
          .insert(
            UsersCompanion.insert(
              id: user.id,
              name: user.name,
              email: user.email,
              avatarPath: Value(user.avatarPath),
              createdAt: user.createdAt,
              lastActiveAt: user.lastActiveAt,
            ),
          );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error creating user in Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> updateUser(UserModel user) async {
    try {
      await (_db.update(_db.users)..where((u) => u.id.equals(user.id))).write(
        UsersCompanion(
          name: Value(user.name),
          email: Value(user.email),
          avatarPath: Value(user.avatarPath),
          lastActiveAt: Value(user.lastActiveAt),
        ),
      );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error updating user in Drift', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> deleteUser(String userId) async {
    try {
      await _db.transaction(() async {
        // Delete user and all associated data (CASCADE will handle foreign keys)
        await (_db.delete(_db.users)..where((u) => u.id.equals(userId))).go();
      });
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error deleting user', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Future<Result<void, AppError>> updateLastActive(String userId) async {
    try {
      await (_db.update(_db.users)..where((u) => u.id.equals(userId))).write(
        UsersCompanion(lastActiveAt: Value(DateTime.now())),
      );
      return const Success(null);
    } catch (e, stack) {
      developer.log('Error updating last active timestamp', error: e);
      return Failure(AppError.database(e.toString(), stackTrace: stack));
    }
  }

  @override
  Stream<List<UserModel>> watchAllUsers() {
    return _db.select(_db.users).watch().map((rows) {
      return rows
          .map(
            (u) => UserModel(
              id: u.id,
              name: u.name,
              email: u.email,
              avatarPath: u.avatarPath,
              createdAt: u.createdAt,
              lastActiveAt: u.lastActiveAt,
            ),
          )
          .toList();
    });
  }
}
