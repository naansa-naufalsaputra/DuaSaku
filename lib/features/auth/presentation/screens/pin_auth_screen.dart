import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../providers/auth_provider.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/ai_mascot.dart';
import '../../../../core/security/security_service.dart';

enum PinMode {
  checking,
  setupEnter,
  setupConfirm,
  unlock,
  changeVerifyOld,
  changeEnterNew,
  changeConfirmNew,
}

class PinAuthState {
  final PinMode mode;
  final String pin;
  final String confirmPin;
  final bool hasError;
  final String message;
  final bool isBiometricsSupported;
  final bool isSuccess;
  final int lockoutSecondsRemaining;

  PinAuthState({
    required this.mode,
    required this.pin,
    required this.confirmPin,
    required this.hasError,
    required this.message,
    required this.isBiometricsSupported,
    this.isSuccess = false,
    this.lockoutSecondsRemaining = 0,
  });

  PinAuthState copyWith({
    PinMode? mode,
    String? pin,
    String? confirmPin,
    bool? hasError,
    String? message,
    bool? isBiometricsSupported,
    bool? isSuccess,
    int? lockoutSecondsRemaining,
  }) {
    return PinAuthState(
      mode: mode ?? this.mode,
      pin: pin ?? this.pin,
      confirmPin: confirmPin ?? this.confirmPin,
      hasError: hasError ?? this.hasError,
      message: message ?? this.message,
      isBiometricsSupported:
          isBiometricsSupported ?? this.isBiometricsSupported,
      isSuccess: isSuccess ?? this.isSuccess,
      lockoutSecondsRemaining:
          lockoutSecondsRemaining ?? this.lockoutSecondsRemaining,
    );
  }
}

class PinAuthNotifier extends AutoDisposeFamilyNotifier<PinAuthState, bool> {
  Timer? _lockoutTimer;

  @override
  PinAuthState build(bool isChangePinMode) {
    ref.onDispose(() {
      _lockoutTimer?.cancel();
    });
    _init(isChangePinMode);
    return PinAuthState(
      mode: PinMode.checking,
      pin: '',
      confirmPin: '',
      hasError: false,
      message: 'pin_auth.checking',
      isBiometricsSupported: false,
      lockoutSecondsRemaining: 0,
    );
  }

  Future<void> _init(bool isChangePinMode) async {
    final authRepository = ref.read(authRepositoryProvider);
    final hasPin = await authRepository.hasPinSet();
    final localAuth = LocalAuthentication();
    final canCheck = await localAuth.canCheckBiometrics;
    final isSupported = await localAuth.isDeviceSupported();

    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_lock_enabled') ?? false;
    final isBiometricsSupported = canCheck && isSupported && biometricEnabled;

    if (isChangePinMode) {
      state = PinAuthState(
        mode: PinMode.changeVerifyOld,
        pin: '',
        confirmPin: '',
        hasError: false,
        message: 'pin_auth.enter_old_pin',
        isBiometricsSupported: false,
      );
    } else if (hasPin) {
      state = PinAuthState(
        mode: PinMode.unlock,
        pin: '',
        confirmPin: '',
        hasError: false,
        message: 'pin_auth.enter_pin_to_unlock',
        isBiometricsSupported: isBiometricsSupported,
      );
    } else {
      state = PinAuthState(
        mode: PinMode.setupEnter,
        pin: '',
        confirmPin: '',
        hasError: false,
        message: 'pin_auth.create_new_pin',
        isBiometricsSupported: isBiometricsSupported,
      );
    }

    await _checkLockout();
  }

  Future<void> _checkLockout() async {
    const secureStorage = FlutterSecureStorage();
    final lockoutUntilStr = await secureStorage.read(key: 'auth_lockout_until');
    if (lockoutUntilStr != null && lockoutUntilStr.isNotEmpty) {
      try {
        final lockoutUntil = DateTime.parse(lockoutUntilStr);
        final difference = lockoutUntil.difference(DateTime.now()).inSeconds;
        if (difference > 0) {
          state = state.copyWith(lockoutSecondsRemaining: difference);
          _startLockoutTimer(difference);
          return;
        }
      } catch (_) {}
    }
    state = state.copyWith(lockoutSecondsRemaining: 0);
  }

  void _startLockoutTimer(int seconds) {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = seconds - timer.tick;
      if (remaining <= 0) {
        timer.cancel();
        state = state.copyWith(
          lockoutSecondsRemaining: 0,
          message: state.mode == PinMode.unlock
              ? 'pin_auth.enter_pin_to_unlock'
              : 'pin_auth.create_new_pin',
        );
      } else {
        state = state.copyWith(lockoutSecondsRemaining: remaining);
      }
    });
  }

  void appendDigit(String digit) {
    if (state.lockoutSecondsRemaining > 0) return;
    if (state.pin.length >= 4) return;
    final newPin = state.pin + digit;

    state = state.copyWith(pin: newPin, hasError: false);

    if (newPin.length == 4) {
      _handlePinCompletion(newPin);
    }
  }

  void removeDigit() {
    if (state.lockoutSecondsRemaining > 0) return;
    if (state.pin.isEmpty) return;
    state = state.copyWith(
      pin: state.pin.substring(0, state.pin.length - 1),
      hasError: false,
    );
  }

  Future<void> _handlePinCompletion(String entered) async {
    final authRepository = ref.read(authRepositoryProvider);

    if (state.mode == PinMode.setupEnter) {
      state = state.copyWith(
        mode: PinMode.setupConfirm,
        confirmPin: entered,
        pin: '',
        message: 'pin_auth.confirm_new_pin',
      );
    } else if (state.mode == PinMode.setupConfirm) {
      if (entered == state.confirmPin) {
        await authRepository.setPin(entered);
      } else {
        HapticFeedback.vibrate();
        state = state.copyWith(
          mode: PinMode.setupEnter,
          pin: '',
          confirmPin: '',
          hasError: true,
          message: 'pin_auth.pin_mismatch',
        );
      }
    } else if (state.mode == PinMode.unlock) {
      final isCorrect = await authRepository.verifyPin(entered);
      if (isCorrect) {
        ref.read(securityProvider.notifier).unlock();
      } else {
        HapticFeedback.vibrate();
        state = state.copyWith(
          pin: '',
          hasError: true,
          message: 'pin_auth.pin_incorrect',
        );
        await _checkLockout();
      }
    } else if (state.mode == PinMode.changeVerifyOld) {
      final isCorrect = await authRepository.verifyPin(entered);
      if (isCorrect) {
        state = state.copyWith(
          mode: PinMode.changeEnterNew,
          pin: '',
          confirmPin: '',
          hasError: false,
          message: 'pin_auth.create_new_pin',
        );
      } else {
        HapticFeedback.vibrate();
        state = state.copyWith(
          pin: '',
          hasError: true,
          message: 'pin_auth.old_pin_incorrect',
        );
        await _checkLockout();
      }
    } else if (state.mode == PinMode.changeEnterNew) {
      state = state.copyWith(
        mode: PinMode.changeConfirmNew,
        confirmPin: entered,
        pin: '',
        hasError: false,
        message: 'pin_auth.confirm_new_pin',
      );
    } else if (state.mode == PinMode.changeConfirmNew) {
      if (entered == state.confirmPin) {
        await authRepository.setPin(entered);
        state = state.copyWith(
          pin: '',
          isSuccess: true,
          message: 'pin_auth.pin_changed_success',
        );
      } else {
        HapticFeedback.vibrate();
        state = state.copyWith(
          mode: PinMode.changeEnterNew,
          pin: '',
          confirmPin: '',
          hasError: true,
          message: 'pin_auth.pin_mismatch',
        );
      }
    }
  }
}

final pinAuthNotifierProvider = NotifierProvider.family
    .autoDispose<PinAuthNotifier, PinAuthState, bool>(() {
      return PinAuthNotifier();
    });

class PinAuthScreen extends ConsumerWidget {
  final bool isChangePinMode;
  const PinAuthScreen({super.key, this.isChangePinMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(pinAuthNotifierProvider(isChangePinMode));
    final notifier = ref.read(
      pinAuthNotifierProvider(isChangePinMode).notifier,
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen<PinAuthState>(pinAuthNotifierProvider(isChangePinMode), (
      prev,
      next,
    ) {
      if (next.isSuccess && isChangePinMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('pin_auth.pin_changed_success'.tr()),
            backgroundColor: const Color(0xFF06B6D4),
          ),
        );
        context.pop();
      }
    });

    if (state.mode == PinMode.checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0E12),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const PremiumBackground(),
          if (isChangePinMode)
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                ),
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Center(child: AiMascot(size: 80)),
                        const SizedBox(height: 16),
                        Text(
                          isChangePinMode
                              ? 'pin_auth.change_pin_title'.tr()
                              : (state.mode == PinMode.unlock
                                    ? 'pin_auth.welcome_back'.tr()
                                    : 'pin_auth.app_security'.tr()),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.lockoutSecondsRemaining > 0
                              ? 'pin_auth.lockout_message'.tr(
                                  args: [
                                    state.lockoutSecondsRemaining.toString(),
                                  ],
                                )
                              : (state.message.isEmpty
                                    ? ''
                                    : state.message.tr()),
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                state.lockoutSecondsRemaining > 0 ||
                                    state.hasError
                                ? Colors.redAccent
                                : (isDark ? Colors.white70 : Colors.black54),
                            fontWeight:
                                state.lockoutSecondsRemaining > 0 ||
                                    state.hasError
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        _buildPinDots(state.pin, state.hasError),
                        const SizedBox(height: 48),
                        _buildNumpad(context, ref, state, notifier),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinDots(String pin, bool hasError) {
    return Animate(
      target: hasError ? 1.0 : 0.0,
      effects: [
        ShakeEffect(
          duration: 400.ms,
          hz: 8,
          curve: Curves.easeInOut,
          offset: const Offset(8, 0),
        ),
      ],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isFilled = index < pin.length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFilled ? const Color(0xFF06B6D4) : Colors.transparent,
              border: Border.all(
                color: isFilled
                    ? const Color(0xFF06B6D4)
                    : Colors.grey.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNumpad(
    BuildContext context,
    WidgetRef ref,
    PinAuthState state,
    PinAuthNotifier notifier,
  ) {
    final isLocked = state.lockoutSecondsRemaining > 0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton(
              context,
              '1',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('1'),
            ),
            _buildKeypadButton(
              context,
              '2',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('2'),
            ),
            _buildKeypadButton(
              context,
              '3',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('3'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton(
              context,
              '4',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('4'),
            ),
            _buildKeypadButton(
              context,
              '5',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('5'),
            ),
            _buildKeypadButton(
              context,
              '6',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('6'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKeypadButton(
              context,
              '7',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('7'),
            ),
            _buildKeypadButton(
              context,
              '8',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('8'),
            ),
            _buildKeypadButton(
              context,
              '9',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('9'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left button: Biometric or empty (Always active, even during lockout)
            state.mode == PinMode.unlock && state.isBiometricsSupported
                ? _buildKeypadButton(
                    context,
                    '',
                    icon: Icons.fingerprint,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(securityProvider.notifier).authenticate();
                    },
                  )
                : const SizedBox(width: 72, height: 72),
            _buildKeypadButton(
              context,
              '0',
              disabled: isLocked,
              onTap: () => notifier.appendDigit('0'),
            ),
            // Right button: Backspace
            _buildKeypadButton(
              context,
              '',
              icon: Icons.backspace_outlined,
              disabled: isLocked,
              onTap: () => notifier.removeDigit(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(
    BuildContext context,
    String text, {
    VoidCallback? onTap,
    IconData? icon,
    bool disabled = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null && !disabled
            ? () {
                HapticFeedback.lightImpact();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(40),
        child: Opacity(
          opacity: disabled ? 0.35 : 1.0,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: disabled ? 0.03 : 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1.5,
              ),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
            ),
            child: icon != null
                ? Icon(
                    icon,
                    size: 28,
                    color: isDark ? Colors.white : Colors.black87,
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
