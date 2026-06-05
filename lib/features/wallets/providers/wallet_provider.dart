import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/models/wallet_model.dart';
import '../domain/wallet_repository_interface.dart';
import '../data/wallet_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/local_db/app_database_provider.dart';
import '../../../core/utils/result.dart';

final walletRepositoryProvider = Provider<WalletRepositoryInterface>((ref) {
  return WalletRepository(ref.watch(appDatabaseProvider));
});

final walletProvider = AsyncNotifierProvider<WalletNotifier, List<WalletModel>>(
  WalletNotifier.new,
);

class WalletNotifier extends AsyncNotifier<List<WalletModel>> {
  StreamSubscription<List<WalletModel>>? _subscription;

  @override
  Future<List<WalletModel>> build() async {
    final repository = ref.watch(walletRepositoryProvider);
    final user = ref.watch(userProvider);

    // Cancel previous subscription on rebuild
    _subscription?.cancel();

    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      _subscription?.cancel();
    });

    if (user?.id == null) {
      return [];
    }

    // Set up reactive stream listening
    _subscription = repository
        .watchWallets(user!.id)
        .listen(
          (wallets) {
            state = AsyncData(wallets);
          },
          onError: (e, stack) {
            state = AsyncError(e, stack);
          },
        );

    // Return initial data
    final result = await repository.getWallets(user.id);
    switch (result) {
      case Success(:final value):
        return value;
      case Failure(:final error):
        throw error;
    }
  }

  Future<void> loadWallets() async {
    final user = ref.read(userProvider);
    if (user?.id == null) return;

    final repository = ref.read(walletRepositoryProvider);
    _subscription?.cancel();
    _subscription = repository
        .watchWallets(user!.id)
        .listen(
          (wallets) {
            state = AsyncData(wallets);
          },
          onError: (e, stack) {
            state = AsyncError(e, stack);
          },
        );
  }

  Future<void> addWallet({
    required String name,
    required String type,
    required double initialBalance,
  }) async {
    final user = ref.read(userProvider);
    if (user?.id == null) throw Exception('User not logged in');

    final repository = ref.read(walletRepositoryProvider);
    final newWallet = WalletModel(
      id: const Uuid().v4(),
      userId: user!.id,
      name: name,
      type: type,
      balance: initialBalance,
      createdAt: DateTime.now(),
    );

    final result = await repository.createWallet(newWallet);
    switch (result) {
      case Success():
        break;
      case Failure(:final error):
        throw error;
    }
  }

  Future<void> updateWallet(WalletModel updatedWallet) async {
    final repository = ref.read(walletRepositoryProvider);
    final result = await repository.updateWallet(updatedWallet);
    switch (result) {
      case Success():
        break;
      case Failure(:final error):
        throw error;
    }
  }

  Future<void> deleteWallet(String walletId) async {
    final repository = ref.read(walletRepositoryProvider);
    final result = await repository.deleteWallet(walletId);
    switch (result) {
      case Success():
        break;
      case Failure(:final error):
        throw error;
    }
  }
}
