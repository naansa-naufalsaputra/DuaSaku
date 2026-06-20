import 'auth_models.dart';

/// Abstract interface for authentication operations.
/// Follows the dependency inversion principle — presentation and provider layers
/// depend on this abstraction rather than the concrete [AuthRepository].
abstract class AuthRepositoryInterface {
  /// Returns the current authentication state.
  AuthState get currentAuthState;

  /// Returns the currently authenticated user, or null if not authenticated.
  User? get currentUser;

  /// Stream of auth state changes.
  Stream<AuthState> get authStateStream;

  /// Check if a PIN has been set by the user.
  Future<bool> hasPinSet();

  /// Set a new PIN and authenticate the user immediately.
  Future<void> setPin(String pin);

  /// Verify the entered PIN against the stored hash.
  /// Returns `true` if the PIN matches, `false` otherwise.
  Future<bool> verifyPin(String pin);

  /// Authenticate using device biometrics (fingerprint, face, etc.).
  /// Returns `true` if authentication succeeded, `false` otherwise.
  Future<bool> authenticateWithBiometrics();

  /// Lock the app (signs the user out locally).
  Future<void> signOut();

  /// Authenticate locally without PIN/biometric (called by SecurityService).
  void authenticateLocally();

  /// Complete first-time onboarding by saving state and optionally setting a PIN.
  Future<void> completeOnboarding({String? pin});

  /// Whether the user has completed onboarding setup.
  bool get isOnboardingCompleted;

  /// Whether the repository has been fully initialized.
  bool get isInitialized;
}
