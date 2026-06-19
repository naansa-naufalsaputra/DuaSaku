import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/utils/category_icon_helper.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/ai_mascot.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/utils/category_translation.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../../transactions/domain/models/category_model.dart';
import '../../../transactions/providers/category_provider.dart';
import '../../../transactions/data/category_repository.dart';
import '../../../transactions/providers/transaction_provider.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Color get _accentColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  }

  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Onboarding Data State
  int _walletCount = 1;
  int _activeWalletIndex = 0;
  final List<TextEditingController> _walletNameControllers = [
    TextEditingController(),
  ];
  final List<TextEditingController> _walletBalanceControllers = [
    TextEditingController(),
  ];
  final List<String> _walletTypes = ['Bank'];
  final List<String?> _walletNameErrors = [null];
  final List<String?> _walletBalanceErrors = [null];

  // Category Selection State
  final List<CategoryModel> _defaultCategories = [
    CategoryModel(
      id: 'food',
      userId: AppConstants.defaultUserId,
      name: 'Food',
      type: 'expense',
      icon: 'restaurant',
      color: '#FF9800',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'transport',
      userId: AppConstants.defaultUserId,
      name: 'Transport',
      type: 'expense',
      icon: 'directions_car',
      color: '#2196F3',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'salary',
      userId: AppConstants.defaultUserId,
      name: 'Salary',
      type: 'income',
      icon: 'attach_money',
      color: '#4CAF50',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'bills',
      userId: AppConstants.defaultUserId,
      name: 'Bills',
      type: 'expense',
      icon: 'receipt',
      color: '#F44336',
      createdAt: DateTime.now(),
    ),
    CategoryModel(
      id: 'shopping',
      userId: AppConstants.defaultUserId,
      name: 'Shopping',
      type: 'expense',
      icon: 'shopping_bag',
      color: '#E91E63',
      createdAt: DateTime.now(),
    ),
  ];
  late final List<bool> _selectedCategories = List.generate(
    _defaultCategories.length,
    (_) => true,
  );

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
      if (_activeWalletIndex >= count) {
        _activeWalletIndex = count - 1;
      }
    });
  }

  Future<void> _completeSetup() async {
    // 1. Save Wallets & Log Initial Balances as Income
    final walletRepo = ref.read(walletRepositoryProvider);
    final transactionRepo = ref.read(transactionRepositoryProvider);
    for (int i = 0; i < _walletCount; i++) {
      final name = _walletNameControllers[i].text.trim();
      final balance = ThousandsFormatter.parse(
        _walletBalanceControllers[i].text,
      );
      final walletId = const Uuid().v4();
      final wallet = WalletModel(
        id: walletId,
        userId: AppConstants.defaultUserId,
        name: name.isEmpty
            ? 'onboarding.wallet_number'.tr(args: [(i + 1).toString()])
            : name,
        type: _walletTypes[i],
        balance: 0.0,
        createdAt: DateTime.now(),
      );
      await walletRepo.createWallet(wallet);

      if (balance > 0) {
        final initialTx = TransactionModel(
          userId: AppConstants.defaultUserId,
          amount: balance,
          categoryId: 'salary',
          type: 'income',
          notes: 'onboarding.initial_balance_notes'.tr(),
          walletId: walletId,
          createdAt: DateTime.now(),
        );
        await transactionRepo.insertTransaction(initialTx);
      }
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

    // Refresh notifier lists
    ref.invalidate(categoryNotifierProvider);
    ref.invalidate(walletProvider);
    ref.invalidate(transactionNotifierProvider);

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
    int? firstErrorIndex;
    for (int i = 0; i < _walletCount; i++) {
      final nameErr = _walletNameControllers[i].text.trim().isEmpty
          ? 'onboarding.wallet_name_required'.tr()
          : null;
      final balErr = _walletBalanceControllers[i].text.trim().isEmpty
          ? 'onboarding.wallet_balance_required'.tr()
          : null;
      setState(() {
        _walletNameErrors[i] = nameErr;
        _walletBalanceErrors[i] = balErr;
      });
      if (nameErr != null || balErr != null) {
        hasError = true;
        firstErrorIndex ??= i;
      }
    }

    if (!hasError) {
      _nextPage();
    } else {
      if (firstErrorIndex != null) {
        setState(() {
          _activeWalletIndex = firstErrorIndex!;
        });
      }
      HapticFeedback.vibrate();
    }
  }

  void _addCustomCategoryDialog() {
    final catNameController = TextEditingController();
    String catType = 'expense';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'onboarding.add_custom_category'.tr(),
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlassInputField(
                    controller: catNameController,
                    labelText: 'onboarding.category_name'.tr(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'onboarding.category_type'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: catType == 'expense'
                                ? const Color(0xFFF44336)
                                : (isDark ? Colors.white10 : Colors.black12),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              setDialogState(() => catType = 'expense'),
                          child: Text('onboarding.expense'.tr()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: catType == 'income'
                                ? const Color(0xFF4CAF50)
                                : (isDark ? Colors.white10 : Colors.black12),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () =>
                              setDialogState(() => catType = 'income'),
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
                  child: Text(
                    'cancel'.tr(),
                    style: const TextStyle(color: Colors.grey),
                  ),
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
                        icon: catType == 'income'
                            ? 'attach_money'
                            : 'shopping_bag',
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
                  child: Text(
                    'onboarding.add'.tr(),
                    style: TextStyle(color: _accentColor),
                  ),
                ),
              ],
            );
          },
        );
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
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
                              color: isActive
                                  ? _accentColor
                                  : Colors.grey.withValues(alpha: 0.5),
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
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
                Text(
                  'onboarding.wallet_count'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 28),
                      onPressed: _walletCount > 1
                          ? () => _adjustWalletFields(_walletCount - 1)
                          : null,
                    ),
                    Text(
                      '$_walletCount',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 28),
                      onPressed: _walletCount < 5
                          ? () => _adjustWalletFields(_walletCount + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Wallet configuration tab bar (if multiple wallets)
            if (_walletCount > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_walletCount, (wIdx) {
                    final isSelected = wIdx == _activeWalletIndex;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Text(
                          'onboarding.wallet_number'.tr(
                            args: [(wIdx + 1).toString()],
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _activeWalletIndex = wIdx;
                            });
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Live virtual card preview for the active wallet
            _buildVirtualCardPreview(_activeWalletIndex, isDark),

            // Active wallet form
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'wallet_name_input',
                  child: GlassInputField(
                    controller: _walletNameControllers[_activeWalletIndex],
                    labelText: 'onboarding.wallet_name'.tr(),
                    hintText: 'onboarding.wallet_name_placeholder'.tr(),
                    errorText: _walletNameErrors[_activeWalletIndex],
                    onChanged: (_) {
                      setState(() {
                        if (_walletNameErrors[_activeWalletIndex] != null) {
                          _walletNameErrors[_activeWalletIndex] = null;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: ['Bank', 'E-Wallet', 'Cash'].map((type) {
                    final isSelected = _walletTypes[_activeWalletIndex] == type;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ChoiceChip(
                          label: Text(
                            'wallets.type_${type.toLowerCase().replaceAll('-', '')}'
                                .tr(),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _walletTypes[_activeWalletIndex] = type;
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'wallet_balance_input',
                  child: GlassInputField(
                    controller: _walletBalanceControllers[_activeWalletIndex],
                    labelText: 'onboarding.wallet_balance'.tr(),
                    hintText: '0',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandsFormatter()],
                    errorText: _walletBalanceErrors[_activeWalletIndex],
                    onChanged: (_) {
                      setState(() {
                        if (_walletBalanceErrors[_activeWalletIndex] != null) {
                          _walletBalanceErrors[_activeWalletIndex] = null;
                        }
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            GlassButton(
              onPressed: () {
                if (_activeWalletIndex < _walletCount - 1) {
                  // Validate current wallet fields first
                  final name = _walletNameControllers[_activeWalletIndex].text
                      .trim();
                  final balanceText =
                      _walletBalanceControllers[_activeWalletIndex].text.trim();
                  setState(() {
                    _walletNameErrors[_activeWalletIndex] = name.isEmpty
                        ? 'onboarding.wallet_name_required'.tr()
                        : null;
                    _walletBalanceErrors[_activeWalletIndex] =
                        balanceText.isEmpty
                        ? 'onboarding.wallet_balance_required'.tr()
                        : null;
                  });
                  if (_walletNameErrors[_activeWalletIndex] == null &&
                      _walletBalanceErrors[_activeWalletIndex] == null) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _activeWalletIndex++;
                    });
                  } else {
                    HapticFeedback.vibrate();
                  }
                } else {
                  _validateAndGoToCategories();
                }
              },
              child: Text(
                _activeWalletIndex < _walletCount - 1
                    ? '${'onboarding.next'.tr()} (${'onboarding.wallet_number'.tr(args: [(_activeWalletIndex + 2).toString()])})'
                    : 'onboarding.next'.tr(),
              ),
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
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

            // Premium Category Selection Grid (2 Columns)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.3,
              ),
              itemCount: _defaultCategories.length,
              itemBuilder: (context, index) {
                final cat = _defaultCategories[index];
                final isSelected = _selectedCategories[index];
                final catColor = _getCategoryColor(cat.color, cat.type);

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedCategories[index] = !isSelected;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? catColor.withValues(alpha: isDark ? 0.15 : 0.08)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.black.withValues(alpha: 0.02)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? catColor
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06)),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: catColor.withValues(alpha: 0.2),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: catColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  CategoryIconHelper.getIconData(cat.icon),
                                  color: catColor,
                                  size: 20,
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cat.name.toLocalizedCategory(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cat.type.tr().toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: catColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Custom categories list
            if (_customCategories.isNotEmpty) ...[
              const Divider(height: 32),
              Text(
                'onboarding.custom_categories_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _customCategories.length,
                itemBuilder: (context, index) {
                  final cat = _customCategories[index];
                  return ListTile(
                    title: Text(cat.name.toLocalizedCategory()),
                    subtitle: Text(cat.type.tr()),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
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

            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _accentColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(Icons.add, color: _accentColor),
              label: Text(
                'onboarding.add_custom_category'.tr(),
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    final currentPinLength = _isConfirmingPin
        ? _confirmPin.length
        : _pin.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
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

            // PIN Dots Indicator with micro-interaction shake on error
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
                        color: isFilled ? _accentColor : Colors.transparent,
                        border: Border.all(
                          color: isFilled
                              ? _accentColor
                              : Colors.grey.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    );
                  }),
                )
                .animate(target: _pinError ? 1.0 : 0.0)
                .shake(hz: 6, duration: 400.ms),
            const SizedBox(height: 40),

            // Custom Glass Numpad
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('1', isDark),
                    _buildNumpadButton('2', isDark),
                    _buildNumpadButton('3', isDark),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('4', isDark),
                    _buildNumpadButton('5', isDark),
                    _buildNumpadButton('6', isDark),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNumpadButton('7', isDark),
                    _buildNumpadButton('8', isDark),
                    _buildNumpadButton('9', isDark),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Skip button inside numpad cell
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.01)
                            : Colors.black.withValues(alpha: 0.01),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _completeSetup();
                          },
                          child: Center(
                            child: Text(
                              'onboarding.skip_security'.tr(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildNumpadButton('0', isDark),
                    // Backspace button inside numpad cell
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.01)
                            : Colors.black.withValues(alpha: 0.01),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _removePinDigit();
                          },
                          child: Center(
                            child: Icon(
                              Icons.backspace_outlined,
                              size: 24,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildNumpadButton(String text, bool isDark) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.lightImpact();
            _appendPinDigit(text);
          },
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String? colorHex, String type) {
    if (colorHex == null || colorHex.isEmpty || colorHex == 'system') {
      return type == 'expense'
          ? const Color(0xFFF43F5E)
          : const Color(0xFF10B981);
    }
    try {
      final hex = colorHex.replaceAll('#', '');
      return Color(int.parse('0xFF$hex'));
    } catch (_) {
      return type == 'expense'
          ? const Color(0xFFF43F5E)
          : const Color(0xFF10B981);
    }
  }

  Widget _buildVirtualCardPreview(int index, bool isDark) {
    final name = _walletNameControllers[index].text.trim();
    final balanceText = _walletBalanceControllers[index].text.trim();
    final type = _walletTypes[index];

    List<Color> cardColors;
    if (type == 'Bank') {
      cardColors = const [
        Color(0xFF1E3A8A),
        Color(0xFF3B82F6),
      ]; // deep blue gradient
    } else if (type == 'E-Wallet') {
      cardColors = const [
        Color(0xFF0F766E),
        Color(0xFF0D9488),
      ]; // teal/cyan gradient
    } else {
      cardColors = const [
        Color(0xFF065F46),
        Color(0xFF10B981),
      ]; // emerald green gradient
    }

    return Container(
      height: 180,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: cardColors
              .map((c) => c.withValues(alpha: isDark ? 0.85 : 0.95))
              .toList(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: cardColors[0].withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: const [0.0, 0.5],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.shade200,
                          width: 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              width: 30,
                              height: 1,
                              color: Colors.amber.shade900.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 1,
                              height: 20,
                              color: Colors.amber.shade900.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'wallets.type_${type.toLowerCase().replaceAll('-', '')}'
                            .tr()
                            .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  name.isEmpty
                      ? 'onboarding.wallet_name_preview'.tr().toUpperCase()
                      : name.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  balanceText.isEmpty ? 'Rp 0' : 'Rp $balanceText',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
