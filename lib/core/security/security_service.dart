import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:ntp/ntp.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../utils/logger.dart';

class SecurityState {
  final bool isLocked;
  final bool isBiometricEnabled;
  final bool isTimeTampered;
  final bool isAuthenticating;
  final bool isInitialized;
  final bool isSecurityEnabled;

  SecurityState({
    this.isLocked = false,
    this.isBiometricEnabled = false,
    this.isTimeTampered = false,
    this.isAuthenticating = false,
    this.isInitialized = false,
    this.isSecurityEnabled = false,
  });

  SecurityState copyWith({
    bool? isLocked,
    bool? isBiometricEnabled,
    bool? isTimeTampered,
    bool? isAuthenticating,
    bool? isInitialized,
    bool? isSecurityEnabled,
  }) {
    return SecurityState(
      isLocked: isLocked ?? this.isLocked,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isTimeTampered: isTimeTampered ?? this.isTimeTampered,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      isInitialized: isInitialized ?? this.isInitialized,
      isSecurityEnabled: isSecurityEnabled ?? this.isSecurityEnabled,
    );
  }
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(() {
  return SecurityNotifier();
});

class SecurityNotifier extends Notifier<SecurityState>
    with WidgetsBindingObserver {
  DateTime? _lastBackgroundTime;
  final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricPrefKey = 'biometric_lock_enabled';
  static const String _securityEnabledPrefKey = 'security_enabled';

  @override
  SecurityState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });
    _init();
    return SecurityState();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool(_biometricPrefKey) ?? false;
    final bool isSecurityEnabled =
        prefs.getBool(_securityEnabledPrefKey) ?? false;

    state = state.copyWith(
      isBiometricEnabled: isEnabled,
      isSecurityEnabled: isSecurityEnabled,
      isLocked: isSecurityEnabled && isEnabled, // If enabled, we start locked
    );

    // Run NTP check in background without blocking initialization
    verifyNtpTime();

    state = state.copyWith(isInitialized: true);

    // If locked initially, trigger authentication after the first frame is rendered
    if (state.isLocked && !state.isTimeTampered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          authenticate();
        });
      });
    }
  }

  Future<void> verifyNtpTime() async {
    try {
      final DateTime localTime = DateTime.now();
      // Fetch current NTP network time with a fallback timeout of 4 seconds
      final DateTime ntpTime = await NTP.now(
        timeout: const Duration(seconds: 4),
      );

      final int driftSeconds = ntpTime.difference(localTime).inSeconds.abs();
      if (driftSeconds > 300) {
        // 5 minutes drift limit
        state = state.copyWith(isTimeTampered: true);
      } else {
        state = state.copyWith(isTimeTampered: false);
      }
    } catch (e, stack) {
      // If NTP check fails due to offline state or network issue, we do not lock the user out,
      // but log the event. Real systems might enforce offline limits.
      ref.read(loggerProvider).error('[SecurityService] NTP check failed', e, stack);
    }
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    if (enabled) {
      try {
        final bool canCheck = await _auth.canCheckBiometrics;
        final bool isDeviceSupported = await _auth.isDeviceSupported();
        final List<BiometricType> available = await _auth
            .getAvailableBiometrics();

        if (!canCheck || !isDeviceSupported || available.isEmpty) {
          ref.read(loggerProvider).warning(
            '[SecurityService] Biometrics not supported or none enrolled',
          );
          return false;
        }

        final bool didAuthenticate = await _auth.authenticate(
          localizedReason: 'profile.biometric_confirm'.tr(),
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );

        if (!didAuthenticate) {
          return false;
        }
      } catch (e, stack) {
        ref.read(loggerProvider).error(
          '[SecurityService] Failed to verify biometric on toggle',
          e,
          stack,
        );
        return false;
      }
    }

    await prefs.setBool(_biometricPrefKey, enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
    return true;
  }

  Future<bool> authenticate() async {
    if (!state.isBiometricEnabled) {
      state = state.copyWith(isLocked: false);
      return true;
    }

    if (state.isAuthenticating) return false;

    try {
      state = state.copyWith(isAuthenticating: true);

      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canAuthenticateWithBiometrics && !isDeviceSupported) {
        state = state.copyWith(isLocked: false, isAuthenticating: false);
        return true;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'pin_auth.biometric_reason'.tr(),
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (didAuthenticate) {
        state = state.copyWith(isLocked: false, isAuthenticating: false);
        ref.read(authRepositoryProvider).authenticateLocally();
        return true;
      } else {
        state = state.copyWith(isAuthenticating: false);
        return false;
      }
    } catch (e, stack) {
      ref.read(loggerProvider).error('[SecurityService] Biometric authentication failed', e, stack);
      state = state.copyWith(isAuthenticating: false);
      return false;
    }
  }

  Future<void> setSecurityEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_securityEnabledPrefKey, enabled);
    state = state.copyWith(isSecurityEnabled: enabled);
    if (!enabled) {
      state = state.copyWith(isLocked: false);
      ref.read(authRepositoryProvider).authenticateLocally();
    }
  }

  void unlock() {
    state = state.copyWith(isLocked: false);
  }

  void lockAppManually() {
    if (state.isSecurityEnabled && state.isBiometricEnabled) {
      state = state.copyWith(isLocked: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!this.state.isSecurityEnabled || !this.state.isBiometricEnabled) return;

    if (state == AppLifecycleState.paused) {
      _lastBackgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null) {
        final durationInBackground = DateTime.now().difference(
          _lastBackgroundTime!,
        );
        if (durationInBackground >= const Duration(seconds: 30)) {
          this.state = this.state.copyWith(isLocked: true);
          authenticate();
        }
        _lastBackgroundTime = null;
      }
    }
  }
}
