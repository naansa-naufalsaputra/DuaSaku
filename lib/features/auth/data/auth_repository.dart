import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:duasaku_app/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:pointycastle/export.dart' as pc;
import '../domain/auth_models.dart';
import '../domain/auth_repository_interface.dart';

/// AuthRepository extends ChangeNotifier so GoRouter can use it
/// directly as a refreshListenable — eliminating stream timing issues.
/// The ChangeNotifier class itself is not banned, only ChangeNotifierProvider.
class AuthRepository extends ChangeNotifier implements AuthRepositoryInterface {
  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  static const String _pinKey = 'user_pin_hash';

  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isOnboardingCompleted = false;
  bool _isInitialized = false;

  @override
  bool get isOnboardingCompleted => _isOnboardingCompleted;

  @override
  bool get isInitialized => _isInitialized;

  /// StreamController that emits the current AuthState whenever
  /// notifyListeners() is called. Used by StreamProvider-based
  /// authStateProvider for reactive state propagation.
  final _authStateController = StreamController<AuthState>.broadcast();

  /// Stream of auth state changes. Emits on every notifyListeners() call.
  @override
  Stream<AuthState> get authStateStream => _authStateController.stream;

  AuthRepository() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isOnboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
      final hasPin = await hasPinSet();
      final isSecurityEnabled = prefs.getBool('security_enabled') ?? true;

      if (_isOnboardingCompleted && (!hasPin || !isSecurityEnabled)) {
        _isAuthenticated = true;
        _currentUser = User(
          id: AppConstants.defaultUserId,
          email: AppConstants.defaultUserEmail,
        );
      }
    } catch (e) {
      debugPrint('[AuthRepository] Failed to initialize state: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_authStateController.isClosed) {
      _authStateController.add(currentAuthState);
    }
  }

  @override
  void dispose() {
    _authStateController.close();
    super.dispose();
  }

  @override
  AuthState get currentAuthState => AuthState(
    session: _isAuthenticated && _currentUser != null
        ? Session(user: _currentUser!, accessToken: 'local_access_token')
        : null,
  );

  @override
  User? get currentUser => _isAuthenticated ? _currentUser : null;

  /// Check if a PIN has been set by the user
  @override
  Future<bool> hasPinSet() async {
    final pinHash = await _secureStorage.read(key: _pinKey);
    return pinHash != null && pinHash.isNotEmpty;
  }

  /// Generate a PBKDF2 hash for the given PIN and salt
  String _pbkdf2Hash(String pin, String saltBase64) {
    final pinBytes = utf8.encode(pin);
    final saltBytes = base64.decode(saltBase64);

    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(saltBytes, 10000, 32));

    final hashBytes = derivator.process(pinBytes);
    return base64.encode(hashBytes);
  }

  /// Helper to generate a random 16-byte salt
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64.encode(values);
  }

  /// Set new PIN and authenticate user immediately
  @override
  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hashed = _pbkdf2Hash(pin, salt);
    final storedValue = 'pbkdf2:10000:$salt:$hashed';
    await _secureStorage.write(key: _pinKey, value: storedValue);

    // Reset lockout counters when setting a new PIN
    await _secureStorage.delete(key: 'auth_failed_attempts');
    await _secureStorage.delete(key: 'auth_lockout_until');

    // Enable lock by default when a PIN is set (ensures E2E testing environment locks correctly)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_lock_enabled', true);
    } catch (e) {
      debugPrint(
        '[AuthRepository] Failed to set default security lock preference: $e',
      );
    }

    _isAuthenticated = true;
    _currentUser = User(
      id: AppConstants.defaultUserId,
      email: AppConstants.defaultUserEmail,
    );
    notifyListeners();
  }

  /// Verify entered PIN
  @override
  Future<bool> verifyPin(String pin) async {
    // Check if locked out
    final lockoutUntilStr = await _secureStorage.read(
      key: 'auth_lockout_until',
    );
    if (lockoutUntilStr != null && lockoutUntilStr.isNotEmpty) {
      try {
        final lockoutUntil = DateTime.parse(lockoutUntilStr);
        if (DateTime.now().isBefore(lockoutUntil)) {
          return false;
        }
      } catch (_) {}
    }

    final storedValue = await _secureStorage.read(key: _pinKey);
    if (storedValue == null || storedValue.isEmpty) return false;

    bool isCorrect = false;

    if (storedValue.startsWith('pbkdf2:')) {
      final parts = storedValue.split(':');
      if (parts.length == 4) {
        final salt = parts[2];
        final expectedHash = parts[3];
        final computedHash = _pbkdf2Hash(pin, salt);
        isCorrect = (computedHash == expectedHash);
      }
    } else {
      // Legacy format: plain SHA-256 (length 64 hex)
      final bytes = utf8.encode(pin);
      final digest = sha256.convert(bytes);
      final hashedInput = digest.toString();
      isCorrect = (storedValue == hashedInput);

      if (isCorrect) {
        // Transparent migration to PBKDF2
        final salt = _generateSalt();
        final pbkdf2Hashed = _pbkdf2Hash(pin, salt);
        final migratedValue = 'pbkdf2:10000:$salt:$pbkdf2Hashed';
        await _secureStorage.write(key: _pinKey, value: migratedValue);
        debugPrint('[AuthRepository] Seamlessly migrated PIN hash to PBKDF2');
      }
    }

    if (isCorrect) {
      _isAuthenticated = true;
      _currentUser = User(
        id: AppConstants.defaultUserId,
        email: AppConstants.defaultUserEmail,
      );
      // Reset lockout counter on success
      await _secureStorage.delete(key: 'auth_failed_attempts');
      await _secureStorage.delete(key: 'auth_lockout_until');

      notifyListeners();
      return true;
    } else {
      // Increment failed attempts
      final attemptsStr =
          await _secureStorage.read(key: 'auth_failed_attempts') ?? '0';
      final attempts = int.parse(attemptsStr) + 1;
      await _secureStorage.write(
        key: 'auth_failed_attempts',
        value: attempts.toString(),
      );

      DateTime? lockoutUntil;
      if (attempts >= 15) {
        lockoutUntil = DateTime.now().add(const Duration(minutes: 30));
      } else if (attempts >= 10) {
        lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
      } else if (attempts >= 5) {
        lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
      }

      if (lockoutUntil != null) {
        await _secureStorage.write(
          key: 'auth_lockout_until',
          value: lockoutUntil.toIso8601String(),
        );
      }
      return false;
    }
  }

  /// Authenticate with biometrics
  @override
  Future<bool> authenticateWithBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isBiometricEnabled =
          prefs.getBool('biometric_lock_enabled') ?? false;
      if (!isBiometricEnabled) return false;

      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();

      if (!canCheck && !isSupported) return false;

      final List<BiometricType> availableBiometrics = await _localAuth
          .getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'pin_auth.biometric_reason'.tr(),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        _isAuthenticated = true;
        _currentUser = User(
          id: AppConstants.defaultUserId,
          email: AppConstants.defaultUserEmail,
        );
        // Reset lockout on successful biometric authentication
        await _secureStorage.delete(key: 'auth_failed_attempts');
        await _secureStorage.delete(key: 'auth_lockout_until');

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Lock the app (signs the user out locally)
  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
    _currentUser = null;
    notifyListeners();
  }

  /// Authenticate locally without PIN/biometric (called by SecurityService)
  @override
  void authenticateLocally() {
    _isAuthenticated = true;
    _currentUser = User(
      id: AppConstants.defaultUserId,
      email: AppConstants.defaultUserEmail,
    );
    // Reset lockout on local authentication
    _secureStorage.delete(key: 'auth_failed_attempts');
    _secureStorage.delete(key: 'auth_lockout_until');
    notifyListeners();
  }

  @override
  Future<void> completeOnboarding({String? pin}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    _isOnboardingCompleted = true;

    if (pin != null && pin.isNotEmpty) {
      await setPin(pin);
    } else {
      _isAuthenticated = true;
      _currentUser = User(
        id: AppConstants.defaultUserId,
        email: AppConstants.defaultUserEmail,
      );
      notifyListeners();
    }
  }
}
