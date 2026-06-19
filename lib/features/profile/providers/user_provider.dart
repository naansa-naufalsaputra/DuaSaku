import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/user_model.dart';
import '../domain/user_repository_interface.dart';
import '../data/user_repository.dart';
import '../../../core/local_db/app_database_provider.dart';
import '../../../core/utils/result.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final userRepositoryProvider = Provider<UserRepositoryInterface>((ref) {
  return UserRepository(ref.watch(appDatabaseProvider));
});

/// Current active user ID provider (persisted in secure storage)
final activeUserIdProvider = NotifierProvider<ActiveUserIdNotifier, String?>(
  () {
    return ActiveUserIdNotifier();
  },
);

class ActiveUserIdNotifier extends Notifier<String?> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'active_user_id';

  @override
  String? build() {
    _loadActiveUserId();
    return null;
  }

  Future<void> _loadActiveUserId() async {
    final userId = await _storage.read(key: _key);
    state = userId ?? 'local_user'; // Default to local_user
  }

  Future<void> switchUser(String userId) async {
    await _storage.write(key: _key, value: userId);
    state = userId;

    // Update last active timestamp
    final repo = ref.read(userRepositoryProvider);
    await repo.updateLastActive(userId);
  }

  Future<void> clearActiveUser() async {
    await _storage.delete(key: _key);
    state = null;
  }
}

/// All users provider (reactive)
final allUsersProvider = StreamProvider<List<UserModel>>((ref) {
  final repository = ref.watch(userRepositoryProvider);
  return repository.watchAllUsers();
});

/// Active user model provider
final activeUserProvider = FutureProvider<UserModel?>((ref) async {
  final activeUserId = ref.watch(activeUserIdProvider);
  if (activeUserId == null) return null;

  final repository = ref.watch(userRepositoryProvider);
  final result = await repository.getUserById(activeUserId);

  return switch (result) {
    Success(:final value) => value,
    Failure() => null,
  };
});

/// User management notifier
final userManagementProvider = Provider<UserManagement>((ref) {
  return UserManagement(ref);
});

class UserManagement {
  final Ref _ref;

  UserManagement(this._ref);

  Future<void> createProfile({
    required String name,
    required String email,
  }) async {
    final repository = _ref.read(userRepositoryProvider);
    final newUser = UserModel(
      id: const Uuid().v4(),
      name: name,
      email: email,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );

    final result = await repository.createUser(newUser);
    switch (result) {
      case Success():
        // Auto-switch to new profile
        await _ref.read(activeUserIdProvider.notifier).switchUser(newUser.id);
      case Failure(:final error):
        throw error;
    }
  }

  Future<void> updateProfile(UserModel user) async {
    final repository = _ref.read(userRepositoryProvider);
    final result = await repository.updateUser(user);

    switch (result) {
      case Success():
        break;
      case Failure(:final error):
        throw error;
    }
  }

  Future<void> deleteProfile(String userId) async {
    final repository = _ref.read(userRepositoryProvider);
    final activeUserId = _ref.read(activeUserIdProvider);

    // Prevent deleting active user (must switch first)
    if (userId == activeUserId) {
      throw Exception(
        'Cannot delete active profile. Switch to another profile first.',
      );
    }

    final result = await repository.deleteUser(userId);
    switch (result) {
      case Success():
        break;
      case Failure(:final error):
        throw error;
    }
  }
}
