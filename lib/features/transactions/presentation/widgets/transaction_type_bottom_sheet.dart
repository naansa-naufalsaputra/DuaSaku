import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/utils/math_parser.dart';
import '../../../../core/utils/category_translation.dart';

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

  // Date and Math Expression Preview
  DateTime _selectedDate = DateTime.now();
  String _mathExpressionPreview = '';

  Color get _accentColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
  }

  @override
  void dispose() {
    _manualAmountController.dispose();
    _manualCategoryController.dispose();
    _manualNotesController.dispose();
    _transferAmountController.dispose();
    _transferNotesController.dispose();
    super.dispose();
  }

  void _updateMathPreview(String text) {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      setState(() {
        _mathExpressionPreview = '';
      });
      return;
    }

    final hasOperators = RegExp(r'[+\-*/()]').hasMatch(cleanText);
    if (hasOperators) {
      final evalResult = MathParser.eval(cleanText);
      if (evalResult != null && evalResult > 0) {
        final formatted = NumberFormat.decimalPattern('id_ID').format(evalResult.toInt());
        setState(() {
          _mathExpressionPreview = '= Rp $formatted';
        });
      } else {
        setState(() {
          _mathExpressionPreview = '';
        });
      }
    } else {
      setState(() {
        _mathExpressionPreview = '';
      });
    }
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
        _mathExpressionPreview = '';
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
            SnackBar(content: Text('bottom_sheet.err_fetch_location'.tr(args: [e.toString()]))),
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

  Future<void> _pickDateTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF0A84FF),
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: Color(0xFF007AFF),
                    surface: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
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



  Future<void> _submitManual() async {
    bool hasError = false;
    setState(() {
      _manualAmountError = _manualAmountController.text.isEmpty
          ? 'bottom_sheet.err_required'.tr()
          : null;
      _manualCategoryError = _manualCategoryController.text.isEmpty
          ? 'bottom_sheet.err_required'.tr()
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
              createdAt: _selectedDate,
            );
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('bottom_sheet.success_save'.tr())));
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
          ? 'bottom_sheet.err_required'.tr()
          : null;
      hasError = _transferAmountError != null;
    });

    if (!hasError) {
      final amount = ThousandsFormatter.parse(_transferAmountController.text);
      if (_transferFromWalletId == _transferToWalletId) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('bottom_sheet.err_same_wallet'.tr())),
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
          ).showSnackBar(SnackBar(content: Text('bottom_sheet.success_transfer'.tr())));
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

  void _showWalletPicker(List<WalletModel> wallets, {bool? isFromWallet}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              Text(
                isFromWallet == true
                    ? 'bottom_sheet.from_wallet'.tr()
                    : isFromWallet == false
                        ? 'bottom_sheet.to_wallet'.tr()
                        : 'bottom_sheet.wallet'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: wallets.length,
                itemBuilder: (context, index) {
                  final wallet = wallets[index];
                  final isSelected = isFromWallet == true
                      ? _transferFromWalletId == wallet.id
                      : isFromWallet == false
                          ? _transferToWalletId == wallet.id
                          : _manualWalletId == wallet.id;
                  return ListTile(
                    leading: Icon(
                      wallet.type == 'Bank'
                          ? Icons.account_balance_rounded
                          : wallet.type == 'E-Wallet'
                              ? Icons.account_balance_wallet_rounded
                              : Icons.payments_rounded,
                      color: isSelected ? const Color(0xFF007AFF) : Colors.grey,
                    ),
                    title: Text(
                      wallet.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(wallet.balance),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF007AFF))
                        : null,
                    onTap: () {
                      setState(() {
                        if (isFromWallet == true) {
                          _transferFromWalletId = wallet.id;
                        } else if (isFromWallet == false) {
                          _transferToWalletId = wallet.id;
                        } else {
                          _manualWalletId = wallet.id;
                        }
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWalletSelectorPill(List<WalletModel> wallets, {bool? isFromWallet}) {
    final String? walletId = isFromWallet == true
        ? _transferFromWalletId
        : isFromWallet == false
            ? _transferToWalletId
            : _manualWalletId;

    final selectedWallet = wallets.firstWhere(
      (w) => w.id == walletId,
      orElse: () => wallets.isNotEmpty
          ? wallets.first
          : WalletModel(
              id: '',
              userId: '',
              name: 'No Wallet',
              type: '',
              balance: 0.0,
              createdAt: DateTime.now(),
            ),
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: GestureDetector(
        onTap: () => _showWalletPicker(wallets, isFromWallet: isFromWallet),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selectedWallet.type == 'Bank'
                    ? Icons.account_balance_rounded
                    : selectedWallet.type == 'E-Wallet'
                        ? Icons.account_balance_wallet_rounded
                        : Icons.payments_rounded,
                size: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                selectedWallet.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: isDark ? Colors.white.withValues(alpha: 0.55) : Colors.black45,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeTab(String type, String label) {
    final isSelected = type == (_isTransferMode ? 'transfer' : _manualType);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            if (type == 'transfer') {
              _isTransferMode = true;
            } else {
              _isTransferMode = false;
              _manualType = type;
              _manualCategoryController.text = type == 'expense' ? 'Food' : 'Salary';
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? _accentColor
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final walletsAsync = ref.watch(walletProvider);
    final walletsList = walletsAsync.valueOrNull ?? [];
    
    // Auto-select defaults
    if (_manualWalletId == null && walletsList.isNotEmpty) {
      _manualWalletId = walletsList.first.id;
    }
    if (_transferFromWalletId == null && walletsList.isNotEmpty) {
      _transferFromWalletId = walletsList[0].id;
    }
    if (_transferToWalletId == null && walletsList.length > 1) {
      _transferToWalletId = walletsList[1].id;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.95,
          minHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: BoxDecoration(
          gradient: isDark
              ? const LinearGradient(
                  colors: [Color(0xFF121212), Color(0xFF121212)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFF9FBFF), Color(0xFFFFFFFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Navigation Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isTransferMode
                          ? 'bottom_sheet.tab_transfer'.tr()
                          : _manualType == 'expense'
                              ? 'bottom_sheet.expense'.tr()
                              : 'bottom_sheet.income'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMMM yyyy', context.locale.toString()).format(_selectedDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.calendar_today_rounded,
                    color: isDark ? Colors.white70 : Colors.black87,
                    size: 20,
                  ),
                  onPressed: _pickDateTime,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 2. Three-Option borderless switcher
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  _buildTypeTab('expense', 'bottom_sheet.expense'.tr()),
                  _buildTypeTab('income', 'bottom_sheet.income'.tr()),
                  _buildTypeTab('transfer', 'bottom_sheet.tab_transfer'.tr()),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Main scrollable content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 3. Oversick Amount Input Zone (Hero)
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Rp ',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.9),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 60, maxWidth: 280),
                              child: IntrinsicWidth(
                                child: Focus(
                                  onFocusChange: (hasFocus) {
                                    if (!hasFocus) {
                                      if (_isTransferMode) {
                                        _evaluateTransferAmountField();
                                      } else {
                                        _evaluateManualAmountField();
                                      }
                                    }
                                  },
                                  child: TextField(
                                    controller: _isTransferMode ? _transferAmountController : _manualAmountController,
                                    keyboardType: TextInputType.text,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: const TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      errorText: _isTransferMode ? _transferAmountError : _manualAmountError,
                                      errorStyle: const TextStyle(height: 0),
                                    ),
                                    inputFormatters: [ThousandsFormatter()],
                                    onChanged: (val) {
                                      if (_isTransferMode) {
                                        if (_transferAmountError != null) {
                                          setState(() => _transferAmountError = null);
                                        }
                                      } else {
                                        if (_manualAmountError != null) {
                                          setState(() => _manualAmountError = null);
                                        }
                                        _updateMathPreview(val);
                                      }
                                    },
                                    onEditingComplete: () {
                                      if (_isTransferMode) {
                                        _evaluateTransferAmountField();
                                      } else {
                                        _evaluateManualAmountField();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_isTransferMode && _mathExpressionPreview.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _mathExpressionPreview,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),

                    // 4. Squishy Wallet Selector Pill
                    if (walletsList.isEmpty)
                      _buildEmptyWalletsCard(isDark)
                    else ...[
                      if (_isTransferMode)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildWalletSelectorPill(walletsList, isFromWallet: true),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            _buildWalletSelectorPill(walletsList, isFromWallet: false),
                          ],
                        )
                      else
                        _buildWalletSelectorPill(walletsList),
                      const SizedBox(height: 24),
                    ],

                    // 5. Premium Category Grid (Manual Only)
                    if (!_isTransferMode) ...[
                      ref.watch(categoryNotifierProvider).when(
                        data: (categories) {
                          final filtered = categories
                              .where((c) => c.type == _manualType)
                              .toList();
                          if (filtered.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  'bottom_sheet.category'.tr().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: isDark ? Colors.white38 : Colors.black38,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.9,
                                ),
                                itemCount: filtered.length > 12 ? 12 : filtered.length,
                                itemBuilder: (context, index) {
                                  final cat = filtered[index];
                                  final isSelected = _manualCategoryController.text.toLowerCase() == cat.name.toLowerCase();
                                  final catColor = _getCategoryColor(cat.color, cat.type);
                                  
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _manualCategoryController.text = cat.name;
                                        if (_manualCategoryError != null) {
                                          _manualCategoryError = null;
                                        }
                                      });
                                    },
                                    child: Column(
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          width: 56,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: catColor.withValues(alpha: 0.12),
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF007AFF) : Colors.transparent,
                                              width: 2.5,
                                            ),
                                          ),
                                          child: Icon(
                                            _getIconData(cat.icon),
                                            color: catColor,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          cat.name.toLocalizedCategory(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected
                                                ? (isDark ? Colors.white : Colors.black87)
                                                : (isDark ? Colors.white54 : Colors.black54),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, st) => Text('Error loading categories: $err'),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 6. Borderless Description Row
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _isTransferMode ? _transferNotesController : _manualNotesController,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: 'bottom_sheet.notes'.tr(),
                                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                                border: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.camera_alt_rounded,
                            color: isDark ? Colors.white38 : Colors.black38,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Saving Row
                    Row(
                      children: [
                        Checkbox(
                          value: _recordLocation,
                          onChanged: _isFetchingLocation ? null : _toggleLocation,
                          activeColor: _accentColor,
                        ),
                        Expanded(
                          child: Text(
                            _isFetchingLocation
                                ? 'bottom_sheet.loc_fetching'.tr()
                                : _recordLocation
                                    ? 'bottom_sheet.loc_saved'.tr(args: [
                                        _latitude!.toStringAsFixed(4),
                                        _longitude!.toStringAsFixed(4)
                                      ])
                                    : (_isTransferMode
                                        ? 'bottom_sheet.loc_save_transfer'.tr()
                                        : 'bottom_sheet.loc_save_tx'.tr()),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // 7. Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isTransferMode ? _submitTransfer : _submitManual,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          _isTransferMode ? 'bottom_sheet.btn_transfer'.tr() : 'bottom_sheet.save_transaction'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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


}
