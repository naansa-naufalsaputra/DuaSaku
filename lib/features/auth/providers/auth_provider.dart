import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

/// Single instance of AuthRepository.
/// AuthRepository still extends ChangeNotifier for GoRouter's refreshListenable.
/// Only the provider wrapper changes from ChangeNotifierProvider to Provider.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repo = AuthRepository();
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Watches the AuthRepository's auth state stream for reactive updates.
/// Emits whenever AuthRepository calls notifyListeners().
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateStream;
});

/// Convenience provider to read the current user.
/// Derives from authStateProvider so it rebuilds on auth state changes.
/// Falls back to reading the repository directly when stream hasn't emitted yet.
final userProvider = Provider<User?>((ref) {
  final asyncAuthState = ref.watch(authStateProvider);
  return asyncAuthState.when(
    data: (state) => state.isAuthenticated ? state.session?.user : null,
    loading: () {
      // Before stream emits, read current state from repository directly
      final repo = ref.read(authRepositoryProvider);
      return repo.currentUser;
    },
    error: (_, _) => null,
  );
});
