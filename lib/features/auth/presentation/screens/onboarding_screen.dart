import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/ai_mascot.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../transactions/providers/category_provider.dart';
import '../../../transactions/data/category_repository.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Onboarding Data State
  int _walletCount = 1;
  final List<TextEditingController> _walletNameControllers = [TextEditingController()];
  final List<TextEditingController> _walletBalanceControllers = [TextEditingController()];
  final List<String> _walletTypes = ['Bank'];
  final List<String?> _walletNameErrors = [null];
  final List<String?> _walletBalanceErrors = [null];

  // Category Selection State
  final List<CategoryModel> _defaultCategories = [
    CategoryModel(id: 'food', userId: AppConstants.defaultUserId, name: 'Food', type: 'expense', icon: 'restaurant', color: '#FF9800', createdAt: DateTime.now()),
    CategoryModel(id: 'transport', userId: AppConstants.defaultUserId, name: 'Transport', type: 'expense', icon: 'directions_car', color: '#2196F3', createdAt: DateTime.now()),
    CategoryModel(id: 'salary', userId: AppConstants.defaultUserId, name: 'Salary', type: 'income', icon: 'attach_money', color: '#4CAF50', createdAt: DateTime.now()),
    CategoryModel(id: 'bills', userId: AppConstants.defaultUserId, name: 'Bills', type: 'expense', icon: 'receipt', color: '#F44336', createdAt: DateTime.now()),
    CategoryModel(id: 'shopping', userId: AppConstants.defaultUserId, name: 'Shopping', type: 'expense', icon: 'shopping_bag', color: '#E91E63', createdAt: DateTime.now()),
  ];
  late final List<bool> _selectedCategories = List.generate(_defaultCategories.length, (_) => true);

  // Custom Categories
  final List<CategoryModel> _customCategories = [];

  // Security / PIN State
  bool _isConfirmingPin = false;
  String _pin = '';
  String _confirmPin = '';
  String _pinMessage = 'onboarding.security_setup_desc';
  bool _pinError = false;

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _walletNameControllers) {
      controller.dispose();
    }
    for (var controller in _walletBalanceControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _adjustWalletFields(int count) {
    if (count > _walletCount) {
      for (int i = _walletCount; i < count; i++) {
        _walletNameControllers.add(TextEditingController());
        _walletBalanceControllers.add(TextEditingController());
        _walletTypes.add('Bank');
        _walletNameErrors.add(null);
        _walletBalanceErrors.add(null);
      }
    } else if (count < _walletCount) {
      for (int i = _walletCount - 1; i >= count; i--) {
        _walletNameControllers[i].dispose();
        _walletNameControllers.removeAt(i);
        _walletBalanceControllers[i].dispose();
        _walletBalanceControllers.removeAt(i);
        _walletTypes.removeAt(i);
        _walletNameErrors.removeAt(i);
        _walletBalanceErrors.removeAt(i);
      }
    }
    setState(() {
      _walletCount = count;
    });
  }

  Future<void> _completeSetup() async {
    // 1. Save Wallets
    final walletRepo = ref.read(walletRepositoryProvider);
    for (int i = 0; i < _walletCount; i++) {
      final name = _walletNameControllers[i].text.trim();
      final balance = ThousandsFormatter.parse(_walletBalanceControllers[i].text);
      final wallet = WalletModel(
        id: const Uuid().v4(),
        userId: AppConstants.defaultUserId,
        name: name.isEmpty ? 'Wallet ${i + 1}' : name,
        type: _walletTypes[i],
        balance: balance,
        createdAt: DateTime.now(),
      );
      await walletRepo.createWallet(wallet);
    }

    // 2. Save Selected Categories & Custom Categories
    final categoryRepo = ref.read(categoryRepositoryProvider);
    
    // Default categories are seeded automatically by the Database onCreate,
    // so we only need to remove the unchecked ones.
    for (int i = 0; i < _defaultCategories.length; i++) {
      if (!_selectedCategories[i]) {
        try {
          await categoryRepo.deleteCategory(_defaultCategories[i].id!);
        } catch (_) {}
      }
    }

    // Insert custom categories if any
    for (final customCat in _customCategories) {
      try {
        await categoryRepo.addCategory(customCat);
      } catch (_) {}
    }

    // Refresh notifier list
    ref.invalidate(categoryNotifierProvider);
    ref.invalidate(walletProvider);

    // 3. Save Preference and PIN state to AuthRepository
    final authRepo = ref.read(authRepositoryProvider);
    if (_pin.isNotEmpty && _pin.length == 4) {
      await authRepo.completeOnboarding(pin: _pin);
    } else {
      await authRepo.completeOnboarding();
    }
  }

  void _nextPage() {
    if (_currentStep < 2) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _validateAndGoToCategories() {
    bool hasError = false;
    for (int i = 0; i < _walletCount; i++) {
      setState(() {
        _walletNameErrors[i] = _walletNameControllers[i].text.trim().isEmpty ? 'onboarding.wallet_name_required'.tr() : null;
        _walletBalanceErrors[i] = _walletBalanceControllers[i].text.trim().isEmpty ? 'onboarding.wallet_balance_required'.tr() : null;
      });
      if (_walletNameErrors[i] != null || _walletBalanceErrors[i] != null) {
        hasError = true;
      }
    }

    if (!hasError) {
      _nextPage();
    } else {
      HapticFeedback.vibrate();
    }
  }

  void _addCustomCategoryDialog() {
    final catNameController = TextEditingController();
    String catType = 'expense';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('onboarding.add_custom_category'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassInputField(
                  controller: catNameController,
                  labelText: 'onboarding.category_name'.tr(),
                ),
                const SizedBox(height: 16),
                Text('onboarding.category_type'.tr(), style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: catType == 'expense' ? const Color(0xFFF44336) : (isDark ? Colors.white10 : Colors.black12),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => setDialogState(() => catType = 'expense'),
                        child: Text('onboarding.expense'.tr()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: catType == 'income' ? const Color(0xFF4CAF50) : (isDark ? Colors.white10 : Colors.black12),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => setDialogState(() => catType = 'income'),
                        child: Text('onboarding.income'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('cancel'.tr(), style: const TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  final name = catNameController.text.trim();
                  if (name.isNotEmpty) {
                    final newCat = CategoryModel(
                      id: const Uuid().v4(),
                      userId: AppConstants.defaultUserId,
                      name: name,
                      type: catType,
                      icon: catType == 'income' ? 'attach_money' : 'shopping_bag',
                      color: catType == 'income' ? '#4CAF50' : '#E91E63',
                      createdAt: DateTime.now(),
                    );
                    setState(() {
                      _customCategories.add(newCat);
                    });
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                  }
                },
                child: Text('onboarding.add'.tr(), style: const TextStyle(color: Color(0xFF06B6D4))),
              ),
            ],
          );
        });
      },
    );
  }

  void _appendPinDigit(String digit) {
    if (!_isConfirmingPin) {
      if (_pin.length >= 4) return;
      setState(() {
        _pin += digit;
        _pinError = false;
      });
      if (_pin.length == 4) {
        setState(() {
          _isConfirmingPin = true;
          _pinMessage = 'onboarding.pin_confirm_desc';
        });
      }
    } else {
      if (_confirmPin.length >= 4) return;
      setState(() {
        _confirmPin += digit;
        _pinError = false;
      });
      if (_confirmPin.length == 4) {
        if (_pin == _confirmPin) {
          _completeSetup();
        } else {
          HapticFeedback.vibrate();
          setState(() {
            _confirmPin = '';
            _pin = '';
            _isConfirmingPin = false;
            _pinError = true;
            _pinMessage = 'pin_auth.pin_mismatch';
          });
        }
      }
    }
  }

  void _removePinDigit() {
    if (!_isConfirmingPin) {
      if (_pin.isEmpty) return;
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _pinError = false;
      });
    } else {
      if (_confirmPin.isEmpty) return;
      setState(() {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        _pinError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header & Stepper Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const AiMascot(size: 48),
                          Text(
                            'onboarding.welcome_title'.tr(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 48), // Balancing Mascot
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Stepper dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          final isActive = index == _currentStep;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF06B6D4) : Colors.grey.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                // Step Page View
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (page) {
                      setState(() {
                        _currentStep = page;
                      });
                    },
                    children: [
                      _buildWalletStep(theme, isDark),
                      _buildCategoryStep(theme, isDark),
                      _buildPinStep(theme, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // STEP 1: Wallets setup
  Widget _buildWalletStep(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'onboarding.wallets_setup'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'onboarding.wallets_setup_desc'.tr(),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Number of wallets selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('onboarding.wallet_count'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 28),
                      onPressed: _walletCount > 1 ? () => _adjustWalletFields(_walletCount - 1) : null,
                    ),
                    Text('$_walletCount', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 28),
                      onPressed: _walletCount < 5 ? () => _adjustWalletFields(_walletCount + 1) : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Wallets forms list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _walletCount,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Wallet #${index + 1}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      ),
                      const SizedBox(height: 12),
                      GlassInputField(
                        controller: _walletNameControllers[index],
                        labelText: 'onboarding.wallet_name'.tr(),
                        hintText: 'e.g. Tunai, Mandiri, Gopay',
                        errorText: _walletNameErrors[index],
                        onChanged: (_) {
                          if (_walletNameErrors[index] != null) {
                            setState(() => _walletNameErrors[index] = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // Wallet Type Dropdown style choice chips
                      Row(
                        children: ['Bank', 'E-Wallet', 'Cash'].map((type) {
                          final isSelected = _walletTypes[index] == type;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: ChoiceChip(
                                label: Text(type),
                                selected: isSelected,
                                onSelected: (_) {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _walletTypes[index] = type;
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      GlassInputField(
                        controller: _walletBalanceControllers[index],
                        labelText: 'onboarding.wallet_balance'.tr(),
                        hintText: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsFormatter()],
                        errorText: _walletBalanceErrors[index],
                        onChanged: (_) {
                          if (_walletBalanceErrors[index] != null) {
                            setState(() => _walletBalanceErrors[index] = null);
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            GlassButton(
              onPressed: _validateAndGoToCategories,
              child: Text('onboarding.next'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 2: Categories Setup
  Widget _buildCategoryStep(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'onboarding.categories_setup'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'onboarding.categories_setup_desc'.tr(),
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Categories list with toggles
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _defaultCategories.length,
              itemBuilder: (context, index) {
                final cat = _defaultCategories[index];
                return SwitchListTile(
                  title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(cat.type.tr()),
                  value: _selectedCategories[index],
                  activeThumbColor: const Color(0xFF06B6D4),
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedCategories[index] = val;
                    });
                  },
                );
              },
            ),

            // Custom categories list
            if (_customCategories.isNotEmpty) ...[
              const Divider(height: 32),
              const Text('Kategori Kustom Anda:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customCategories.length,
                itemBuilder: (context, index) {
                  final cat = _customCategories[index];
                  return ListTile(
                    title: Text(cat.name),
                    subtitle: Text(cat.type.tr()),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _customCategories.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF06B6D4)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add, color: Color(0xFF06B6D4)),
              label: Text('onboarding.add_custom_category'.tr(), style: const TextStyle(color: Color(0xFF06B6D4), fontWeight: FontWeight.bold)),
              onPressed: _addCustomCategoryDialog,
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onPressed: _previousPage,
                    child: Text('onboarding.back'.tr()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassButton(
                    onPressed: _nextPage,
                    child: Text('onboarding.next'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // STEP 3: Security Setup (PIN Entry)
  Widget _buildPinStep(ThemeData theme, bool isDark) {
    final currentPinLength = _isConfirmingPin ? _confirmPin.length : _pin.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'onboarding.security_setup'.tr(),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _pinMessage.tr(),
              style: TextStyle(
                fontSize: 14,
                color: _pinError ? Colors.redAccent : Colors.grey,
                fontWeight: _pinError ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < currentPinLength;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? const Color(0xFF06B6D4) : Colors.transparent,
                    border: Border.all(
                      color: isFilled ? const Color(0xFF06B6D4) : Colors.grey.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 40),

            // Custom Numpad
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('1'),
                    _buildNumpadButton('2'),
                    _buildNumpadButton('3'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('4'),
                    _buildNumpadButton('5'),
                    _buildNumpadButton('6'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('7'),
                    _buildNumpadButton('8'),
                    _buildNumpadButton('9'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Left button: Skip Security (completely skip PIN setup)
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _completeSetup();
                        },
                        child: Text(
                          'onboarding.skip_security'.tr(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    _buildNumpadButton('0'),
                    // Right button: Backspace
                    IconButton(
                      icon: const Icon(Icons.backspace_outlined, size: 28),
                      onPressed: _removePinDigit,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onPressed: _previousPage,
                    child: Text('onboarding.back'.tr()),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GlassButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _completeSetup();
                    },
                    child: Text('onboarding.finish'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpadButton(String text) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _appendPinDigit(text);
        },
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
            color: Colors.white.withValues(alpha: 0.02),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }
}
