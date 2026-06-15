import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:duasaku_app/core/constants/app_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../domain/auth_repository_interface.dart';

class User {
  final String id;
  final String email;

  User({required this.id, required this.email});
}

class Session {
  final User user;
  final String accessToken;

  Session({required this.user, required this.accessToken});
}

class AuthResponse {
  final Session? session;
  final User? user;

  AuthResponse({this.session, this.user});
}

class AuthState {
  final Session? session;

  AuthState({this.session});

  bool get isAuthenticated => session != null;
}

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

  /// Internal helper to hash PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Set new PIN and authenticate user immediately
  @override
  Future<void> setPin(String pin) async {
    final hashed = _hashPin(pin);
    await _secureStorage.write(key: _pinKey, value: hashed);

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
    final storedHash = await _secureStorage.read(key: _pinKey);
    if (storedHash == null) return false;

    final hashedInput = _hashPin(pin);
    if (storedHash == hashedInput) {
      _isAuthenticated = true;
      _currentUser = User(
        id: AppConstants.defaultUserId,
        email: AppConstants.defaultUserEmail,
      );
      notifyListeners();
      return true;
    }
    return false;
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
