import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/utils/math_parser.dart';

import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../providers/transaction_provider.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../providers/category_provider.dart';

class TransactionTypeBottomSheet extends ConsumerStatefulWidget {
  const TransactionTypeBottomSheet({super.key});

  @override
  ConsumerState<TransactionTypeBottomSheet> createState() =>
      _TransactionTypeBottomSheetState();
}

class _TransactionTypeBottomSheetState
    extends ConsumerState<TransactionTypeBottomSheet> {
  bool _isTransferMode = false;

  // Location State
  bool _recordLocation = false;
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;

  // Manual Input State
  final _manualAmountController = TextEditingController();
  final _manualCategoryController = TextEditingController(text: 'Food');
  final _manualNotesController = TextEditingController();
  String? _manualAmountError;
  String? _manualCategoryError;
  String? _manualWalletId;
  String _manualType = 'expense';

  // Transfer State
  final _transferAmountController = TextEditingController();
  final _transferNotesController = TextEditingController();
  String? _transferAmountError;
  String? _transferFromWalletId;
  String? _transferToWalletId;

  @override
  void dispose() {
    _manualAmountController.dispose();
    _manualCategoryController.dispose();
    _manualNotesController.dispose();
    _transferAmountController.dispose();
    _transferNotesController.dispose();
    super.dispose();
  }

  void _evaluateManualAmountField() {
    final text = _manualAmountController.text.trim();
    if (text.isEmpty) return;
    final result = MathParser.eval(text);
    if (result != null && result > 0) {
      final formatted = NumberFormat.decimalPattern(
        'id_ID',
      ).format(result.toInt());
      setState(() {
        _manualAmountController.text = formatted;
      });
    }
  }

  void _evaluateTransferAmountField() {
    final text = _transferAmountController.text.trim();
    if (text.isEmpty) return;
    final result = MathParser.eval(text);
    if (result != null && result > 0) {
      final formatted = NumberFormat.decimalPattern(
        'id_ID',
      ).format(result.toInt());
      setState(() {
        _transferAmountController.text = formatted;
      });
    }
  }

  Future<void> _toggleLocation(bool? value) async {
    if (value == true) {
      setState(() {
        _isFetchingLocation = true;
      });
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          final requested = await Geolocator.requestPermission();
          if (requested == LocationPermission.denied ||
              requested == LocationPermission.deniedForever) {
            setState(() {
              _recordLocation = false;
              _isFetchingLocation = false;
            });
            return;
          }
        }

        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );

        setState(() {
          _recordLocation = true;
          _latitude = position.latitude;
          _longitude = position.longitude;
          _isFetchingLocation = false;
        });
      } catch (e) {
        setState(() {
          _recordLocation = false;
          _isFetchingLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mendapatkan lokasi: $e')),
          );
        }
      }
    } else {
      setState(() {
        _recordLocation = false;
        _latitude = null;
        _longitude = null;
      });
    }
  }

  IconData _getIconData(String? name) {
    switch (name) {
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'local_cafe':
        return Icons.local_cafe_rounded;
      case 'attach_money':
        return Icons.attach_money_rounded;
      case 'receipt':
        return Icons.receipt_rounded;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'directions_car':
        return Icons.directions_car_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'electrical_services':
        return Icons.electrical_services_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'wifi':
        return Icons.wifi_rounded;
      case 'medical_services':
        return Icons.medical_services_rounded;
      case 'sports_esports':
        return Icons.sports_esports_rounded;
      case 'movie':
        return Icons.movie_rounded;
      case 'flight':
        return Icons.flight_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'card_giftcard':
        return Icons.card_giftcard_rounded;
      case 'work':
        return Icons.work_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'build':
        return Icons.build_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'payments':
        return Icons.payments_rounded;
      default:
        return Icons.category_rounded;
    }
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

  List<Color> _getGradientForType(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
      case 'e-wallet':
        return const [Color(0xFF8B5CF6), Color(0xFF6D28D9)];
      case 'cash':
        return const [Color(0xFF10B981), Color(0xFF047857)];
      default:
        return const [Color(0xFF6366F1), Color(0xFF4338CA)];
    }
  }

  Future<void> _submitManual() async {
    bool hasError = false;
    setState(() {
      _manualAmountError = _manualAmountController.text.isEmpty
          ? 'Required'
          : null;
      _manualCategoryError = _manualCategoryController.text.isEmpty
          ? 'Required'
          : null;
      hasError = _manualAmountError != null || _manualCategoryError != null;
    });

    if (!hasError) {
      final amount = ThousandsFormatter.parse(_manualAmountController.text);
      final category = _manualCategoryController.text;
      final notes = _manualNotesController.text;
      try {
        await ref
            .read(transactionNotifierProvider.notifier)
            .createTransaction(
              amount: amount,
              category: category,
              type: _manualType,
              notes: notes,
              walletId: _manualWalletId,
              latitude: _latitude,
              longitude: _longitude,
            );
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Transaction Saved')));
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    } else {
      HapticFeedback.vibrate();
    }
  }

  Future<void> _submitTransfer() async {
    bool hasError = false;
    setState(() {
      _transferAmountError = _transferAmountController.text.isEmpty
          ? 'Required'
          : null;
      hasError = _transferAmountError != null;
    });

    if (!hasError) {
      final amount = ThousandsFormatter.parse(_transferAmountController.text);
      if (_transferFromWalletId == _transferToWalletId) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot transfer to same wallet')),
        );
        return;
      }
      if (_transferFromWalletId == null || _transferToWalletId == null) {
        HapticFeedback.vibrate();
        return;
      }
      try {
        await ref
            .read(transactionNotifierProvider.notifier)
            .createTransfer(
              amount: amount,
              fromWalletId: _transferFromWalletId!,
              toWalletId: _transferToWalletId!,
              notes: _transferNotesController.text,
              latitude: _latitude,
              longitude: _longitude,
            );
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Transfer Saved')));
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          HapticFeedback.vibrate();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    } else {
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletsAsync = ref.watch(walletProvider);
    final walletsList = walletsAsync.valueOrNull ?? [];
    final hasEnoughWalletsForTransfer = walletsList.length >= 2;
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Segmented Control Header
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isTransferMode = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isTransferMode
                              ? Colors.deepPurpleAccent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_isTransferMode
                                ? Colors.deepPurpleAccent
                                : Colors.grey.withValues(alpha: 0.2),
                            width: !_isTransferMode ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          'bottom_sheet.tab_manual'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_isTransferMode
                                ? Colors.deepPurpleAccent
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isTransferMode = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isTransferMode
                              ? Colors.deepPurpleAccent.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isTransferMode
                                ? Colors.deepPurpleAccent
                                : Colors.grey.withValues(alpha: 0.2),
                            width: _isTransferMode ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          'bottom_sheet.tab_transfer'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isTransferMode
                                ? Colors.deepPurpleAccent
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mode Content
              if (!_isTransferMode)
                _buildManualLayout(isDark, walletsAsync, formatCurrency)
              else
                _buildTransferLayout(
                  isDark,
                  walletsAsync,
                  hasEnoughWalletsForTransfer,
                  formatCurrency,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualLayout(
    bool isDark,
    AsyncValue<List<WalletModel>> walletsAsync,
    NumberFormat formatCurrency,
  ) {
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Amount Input
        Semantics(
          label: 'amount_input',
          child: Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                _evaluateManualAmountField();
              }
            },
            child: GlassInputField(
              controller: _manualAmountController,
              labelText: 'bottom_sheet.amount'.tr(),
              keyboardType: TextInputType.text,
              inputFormatters: [ThousandsFormatter()],
              errorText: _manualAmountError,
              onChanged: (_) {
                if (_manualAmountError != null) {
                  setState(() => _manualAmountError = null);
                }
              },
              onEditingComplete: _evaluateManualAmountField,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Type Selector (Expense vs Income)
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _manualType = 'expense';
                    // Re-default category based on new type to ensure valid selection
                    _manualCategoryController.text = 'Food';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _manualType == 'expense'
                        ? const Color(0xFFF43F5E).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _manualType == 'expense'
                          ? const Color(0xFFF43F5E)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: _manualType == 'expense' ? 2 : 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_downward,
                        color: Color(0xFFF43F5E),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'EXPENSE',
                        style: TextStyle(
                          color: Color(0xFFF43F5E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _manualType = 'income';
                    _manualCategoryController.text = 'Salary';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _manualType == 'income'
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _manualType == 'income'
                          ? const Color(0xFF10B981)
                          : Colors.grey.withValues(alpha: 0.2),
                      width: _manualType == 'income' ? 2 : 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_upward,
                        color: Color(0xFF10B981),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'INCOME',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Category Selector (Horizontal chips)
        categoriesAsync.when(
          data: (categories) {
            final filtered = categories
                .where((c) => c.type == _manualType)
                .toList();
            if (filtered.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'bottom_sheet.category'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: filtered.map((cat) {
                    final isSelected =
                        _manualCategoryController.text.toLowerCase() ==
                        cat.name.toLowerCase();
                    final catColor = _getCategoryColor(cat.color, cat.type);

                    return ChoiceChip(
                      avatar: Icon(
                        _getIconData(cat.icon),
                        color: isSelected ? Colors.white : catColor,
                        size: 16,
                      ),
                      label: Text(cat.name),
                      selected: isSelected,
                      selectedColor: catColor,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _manualCategoryController.text = cat.name;
                            if (_manualCategoryError != null) {
                              _manualCategoryError = null;
                            }
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Text('Error loading categories: $err'),
        ),

        // 4. Wallet Card Selector
        walletsAsync.when(
          data: (wallets) {
            if (wallets.isEmpty) {
              return _buildEmptyWalletsCard(isDark);
            }

            // Auto-select first wallet if none selected
            if (_manualWalletId == null && wallets.isNotEmpty) {
              _manualWalletId = wallets.first.id;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'bottom_sheet.wallet'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 74,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final isSelected = _manualWalletId == wallet.id;
                      final gradient = _getGradientForType(wallet.type);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _manualWalletId = wallet.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12, bottom: 4),
                          padding: const EdgeInsets.all(12),
                          width: 130,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.first.withValues(
                                  alpha: isSelected ? 0.4 : 0.15,
                                ),
                                blurRadius: isSelected ? 8 : 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                wallet.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                formatCurrency.format(wallet.balance),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => _buildErrorWalletsCard(isDark, err.toString()),
        ),

        // 5. Notes Input
        GlassInputField(
          controller: _manualNotesController,
          labelText: 'bottom_sheet.notes'.tr(),
        ),
        const SizedBox(height: 16),

        // Location Checkbox
        Row(
          children: [
            Checkbox(
              value: _recordLocation,
              onChanged: _isFetchingLocation ? null : _toggleLocation,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: Text(
                _isFetchingLocation
                    ? 'Mencari lokasi...'
                    : _recordLocation
                    ? 'Lokasi disimpan (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                    : 'Simpan lokasi transaksi',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            if (_isFetchingLocation)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // 6. Save Button
        Semantics(
          label: 'save_transaction_button',
          child: GlassButton(
            onPressed: _submitManual,
            child: Text('bottom_sheet.save_transaction'.tr()),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferLayout(
    bool isDark,
    AsyncValue<List<WalletModel>> walletsAsync,
    bool hasEnoughWalletsForTransfer,
    NumberFormat formatCurrency,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Amount Input
        Focus(
          onFocusChange: (hasFocus) {
            if (!hasFocus) {
              _evaluateTransferAmountField();
            }
          },
          child: GlassInputField(
            controller: _transferAmountController,
            labelText: 'bottom_sheet.amount'.tr(),
            keyboardType: TextInputType.text,
            inputFormatters: [ThousandsFormatter()],
            errorText: _transferAmountError,
            onChanged: (_) {
              if (_transferAmountError != null) {
                setState(() => _transferAmountError = null);
              }
            },
            onEditingComplete: _evaluateTransferAmountField,
          ),
        ),
        const SizedBox(height: 16),

        // 2. Wallets Selector
        walletsAsync.when(
          data: (wallets) {
            if (wallets.length < 2) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'bottom_sheet.transfer_requires_wallets'.tr(),
                      style: TextStyle(
                        color: isDark ? Colors.amber[200] : Colors.amber[800],
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        variant: GlassButtonVariant.secondary,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                          context.push('/manage-wallets');
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_card, size: 16),
                            const SizedBox(width: 8),
                            Text('bottom_sheet.btn_manage_wallets'.tr()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Auto-default from and to wallets
            if (_transferFromWalletId == null && wallets.isNotEmpty) {
              _transferFromWalletId = wallets[0].id;
            }
            if (_transferToWalletId == null && wallets.length > 1) {
              _transferToWalletId = wallets[1].id;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FROM WALLET
                Text(
                  'bottom_sheet.from_wallet'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 74,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final isSelected = _transferFromWalletId == wallet.id;
                      final gradient = _getGradientForType(wallet.type);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _transferFromWalletId = wallet.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12, bottom: 4),
                          padding: const EdgeInsets.all(12),
                          width: 130,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.first.withValues(
                                  alpha: isSelected ? 0.4 : 0.15,
                                ),
                                blurRadius: isSelected ? 8 : 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                wallet.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                formatCurrency.format(wallet.balance),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // TO WALLET
                Text(
                  'bottom_sheet.to_wallet'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 74,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final wallet = wallets[index];
                      final isSelected = _transferToWalletId == wallet.id;
                      final gradient = _getGradientForType(wallet.type);

                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _transferToWalletId = wallet.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12, bottom: 4),
                          padding: const EdgeInsets.all(12),
                          width: 130,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.first.withValues(
                                  alpha: isSelected ? 0.4 : 0.15,
                                ),
                                blurRadius: isSelected ? 8 : 4,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                wallet.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                formatCurrency.format(wallet.balance),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => _buildErrorWalletsCard(isDark, err.toString()),
        ),

        // 3. Notes Input
        GlassInputField(
          controller: _transferNotesController,
          labelText: 'bottom_sheet.notes'.tr(),
        ),
        const SizedBox(height: 16),

        // Location Checkbox
        Row(
          children: [
            Checkbox(
              value: _recordLocation,
              onChanged: _isFetchingLocation ? null : _toggleLocation,
              activeColor: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: Text(
                _isFetchingLocation
                    ? 'Mencari lokasi...'
                    : _recordLocation
                    ? 'Lokasi disimpan (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                    : 'Simpan lokasi transfer',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            if (_isFetchingLocation)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 20),

        // 4. Save Button
        GlassButton(
          onPressed: hasEnoughWalletsForTransfer ? _submitTransfer : null,
          child: Text('bottom_sheet.btn_transfer'.tr()),
        ),
      ],
    );
  }

  Widget _buildEmptyWalletsCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'bottom_sheet.no_wallet_warning'.tr(),
            style: TextStyle(
              color: isDark ? Colors.amber[200] : Colors.amber[800],
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              variant: GlassButtonVariant.secondary,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.pop();
                context.push('/manage-wallets');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_card, size: 16),
                  const SizedBox(width: 8),
                  Text('bottom_sheet.btn_create_wallet'.tr()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWalletsCard(bool isDark, String errorText) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Failed to load wallets: $errorText',
            style: TextStyle(
              color: isDark ? Colors.red[200] : Colors.red[800],
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              variant: GlassButtonVariant.secondary,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.pop();
                context.push('/manage-wallets');
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.settings, size: 16),
                  SizedBox(width: 8),
                  Text('Go to Wallet Settings'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
