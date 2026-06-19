import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/utils/thousands_formatter.dart';
import '../../../../core/utils/math_preview_parser.dart';

import '../../providers/transaction_provider.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../providers/category_provider.dart';
import '../../domain/models/transaction_model.dart';
import '../../../../core/providers/settings_provider.dart';
import 'home/manual_transaction_form.dart';
import 'home/transfer_transaction_form.dart';

enum TransactionType { expense, income, transfer }

class TransactionTypeBottomSheet extends ConsumerStatefulWidget {
  final TransactionModel? transaction;
  const TransactionTypeBottomSheet({super.key, this.transaction});

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

  TransactionType get activeTransactionType {
    if (_isTransferMode) return TransactionType.transfer;
    return _manualType == 'expense'
        ? TransactionType.expense
        : TransactionType.income;
  }

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      final tx = widget.transaction!;
      _isTransferMode = (tx.type == 'transfer');
      _selectedDate = tx.createdAt;
      _latitude = tx.latitude;
      _longitude = tx.longitude;
      _recordLocation = (tx.latitude != null && tx.longitude != null);

      if (_isTransferMode) {
        _transferAmountController.text = NumberFormat.decimalPattern(
          'id_ID',
        ).format(tx.amount.toInt());
        _transferNotesController.text = tx.notes;
        _transferFromWalletId = tx.fromWalletId;
        _transferToWalletId = tx.toWalletId;
      } else {
        _manualType = tx.type;
        _manualAmountController.text = NumberFormat.decimalPattern(
          'id_ID',
        ).format(tx.amount.toInt());
        _manualCategoryController.text = tx.categoryId;
        _manualNotesController.text = tx.notes;
        _manualWalletId = tx.walletId;
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final isAutoGeolocate = ref.read(autoGeolocationProvider);
          if (isAutoGeolocate) {
            _toggleLocation(true);
          }
        }
      });
    }
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
    final currencySymbol = ref.read(currencySymbolProvider);
    if (!MathPreviewParser.hasOperators(text)) {
      setState(() {
        _mathExpressionPreview = '';
      });
      return;
    }

    final sanitized = MathPreviewParser.sanitizeExpression(
      text,
      currencySymbol,
    );
    final evalResult = MathPreviewParser.evaluate(sanitized);

    if (evalResult != null && evalResult > 0) {
      final formatted = ref.read(currencyFormatterProvider).format(evalResult);
      setState(() {
        _mathExpressionPreview = '= $formatted';
      });
    } else {
      setState(() {
        _mathExpressionPreview = '';
      });
    }
  }

  void _evaluateManualAmountField() {
    final text = _manualAmountController.text.trim();
    if (text.isEmpty) return;
    final currencySymbol = ref.read(currencySymbolProvider);
    final sanitized = MathPreviewParser.sanitizeExpression(
      text,
      currencySymbol,
    );
    final result = MathPreviewParser.evaluate(sanitized);
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
    final currencySymbol = ref.read(currencySymbolProvider);
    final sanitized = MathPreviewParser.sanitizeExpression(
      text,
      currencySymbol,
    );
    final result = MathPreviewParser.evaluate(sanitized);
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
            // Reactive rollback: auto-disable toggle if permission denied
            ref.read(autoGeolocationProvider.notifier).setEnabled(false);
            return;
          }
        } else if (permission == LocationPermission.deniedForever) {
          setState(() {
            _recordLocation = false;
            _isFetchingLocation = false;
          });
          ref.read(autoGeolocationProvider.notifier).setEnabled(false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('bottom_sheet.location_revoked'.tr()),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
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
        // Reactive rollback on any location error when auto-geo was active
        final isAutoGeo = ref.read(autoGeolocationProvider);
        if (isAutoGeo) {
          ref.read(autoGeolocationProvider.notifier).setEnabled(false);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'bottom_sheet.err_fetch_location'.tr(args: [e.toString()]),
              ),
            ),
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
        if (widget.transaction != null) {
          final updatedTx = widget.transaction!.copyWith(
            amount: amount,
            categoryId: category,
            type: _manualType,
            notes: notes,
            walletId: _manualWalletId,
            latitude: _latitude,
            longitude: _longitude,
            createdAt: _selectedDate,
          );
          await ref
              .read(transactionNotifierProvider.notifier)
              .updateTransaction(updatedTx, widget.transaction!);
        } else {
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
        }
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('bottom_sheet.success_save'.tr())),
          );
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
        if (widget.transaction != null) {
          final updatedTx = widget.transaction!.copyWith(
            amount: amount,
            categoryId: 'transfer',
            type: 'transfer',
            notes: _transferNotesController.text,
            fromWalletId: _transferFromWalletId,
            toWalletId: _transferToWalletId,
            walletId: null,
            latitude: _latitude,
            longitude: _longitude,
            createdAt: _selectedDate,
          );
          await ref
              .read(transactionNotifierProvider.notifier)
              .updateTransaction(updatedTx, widget.transaction!);
        } else {
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
        }
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('bottom_sheet.success_transfer'.tr())),
          );
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
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      ref
                          .watch(currencyFormatterProvider)
                          .format(wallet.balance),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF007AFF),
                          )
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

  Widget _buildWalletSelectorPill(
    List<WalletModel> wallets, {
    bool? isFromWallet,
  }) {
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.55)
                    : Colors.black45,
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

              final categories =
                  ref.read(categoryNotifierProvider).valueOrNull ?? [];
              final expenseCategoriesList = categories
                  .where((c) => c.type == 'expense')
                  .toList();
              final incomeCategoriesList = categories
                  .where((c) => c.type == 'income')
                  .toList();

              if (type == 'expense') {
                if (expenseCategoriesList.isNotEmpty) {
                  _manualCategoryController.text =
                      expenseCategoriesList.first.name;
                } else {
                  _manualCategoryController.text = 'Food';
                }
              } else if (type == 'income') {
                if (incomeCategoriesList.isNotEmpty) {
                  _manualCategoryController.text =
                      incomeCategoriesList.first.name;
                } else {
                  _manualCategoryController.text = 'Salary';
                }
              }
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? _accentColor : Colors.transparent,
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
                      DateFormat(
                        'dd MMMM yyyy',
                        context.locale.toString(),
                      ).format(_selectedDate),
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
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
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
                child: _isTransferMode
                    ? TransferTransactionForm(
                        amountController: _transferAmountController,
                        notesController: _transferNotesController,
                        amountError: _transferAmountError,
                        wallets: walletsList,
                        recordLocation: _recordLocation,
                        onRecordLocationChanged: (val) => _toggleLocation(val),
                        isFetchingLocation: _isFetchingLocation,
                        onSubmit: _submitTransfer,
                        onAmountChanged: _updateMathPreview,
                        onAmountFocusLost: _evaluateTransferAmountField,
                        currencySymbol: ref.watch(currencySymbolProvider),
                        fromWalletSelectorWidget: _buildWalletSelectorPill(
                          walletsList,
                          isFromWallet: true,
                        ),
                        toWalletSelectorWidget: _buildWalletSelectorPill(
                          walletsList,
                          isFromWallet: false,
                        ),
                      )
                    : ManualTransactionForm(
                        amountController: _manualAmountController,
                        notesController: _manualNotesController,
                        activeCategory: _manualCategoryController.text,
                        onCategorySelected: (catName) {
                          setState(() {
                            _manualCategoryController.text = catName;
                            if (_manualCategoryError != null) {
                              _manualCategoryError = null;
                            }
                          });
                        },
                        amountError: _manualAmountError,
                        categoryError: _manualCategoryError,
                        selectedWalletId: _manualWalletId,
                        onWalletSelected: (walletId) {
                          setState(() {
                            _manualWalletId = walletId;
                          });
                        },
                        transactionType: _manualType,
                        wallets: walletsList,
                        categories:
                            ref.read(categoryNotifierProvider).valueOrNull ??
                            [],
                        recordLocation: _recordLocation,
                        onRecordLocationChanged: (val) => _toggleLocation(val),
                        isFetchingLocation: _isFetchingLocation,
                        onSubmit: _submitManual,
                        mathExpressionPreview: _mathExpressionPreview,
                        onAmountChanged: _updateMathPreview,
                        onAmountFocusLost: _evaluateManualAmountField,
                        currencySymbol: ref.watch(currencySymbolProvider),
                        walletSelectorWidget: _buildWalletSelectorPill(
                          walletsList,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
