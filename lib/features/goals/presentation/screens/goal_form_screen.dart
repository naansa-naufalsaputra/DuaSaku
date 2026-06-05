import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/thousands_formatter.dart';

import '../../../../core/utils/result.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../wallets/domain/models/wallet_model.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../domain/models/goal_model.dart';
import '../../domain/models/goal_status.dart';
import '../../providers/goal_provider.dart';

/// Available icons for goal selection.
const _goalIcons = [
  '🎯',
  '✈️',
  '🏠',
  '🚗',
  '💻',
  '📱',
  '🎓',
  '💍',
  '🏖️',
  '🎮',
  '👶',
  '🐶',
  '💰',
  '🏥',
  '🎁',
  '📚',
];

/// Available colors for goal selection.
const _goalColors = [
  Color(0xFF6C63FF), // Purple
  Color(0xFF00BFA5), // Teal
  Color(0xFFFF6B6B), // Red
  Color(0xFFFFB74D), // Orange
  Color(0xFF4FC3F7), // Blue
  Color(0xFF81C784), // Green
  Color(0xFFBA68C8), // Violet
  Color(0xFFFFD54F), // Yellow
  Color(0xFFF06292), // Pink
  Color(0xFF4DB6AC), // Cyan
];

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goal});

  /// If non-null, the screen is in edit mode and pre-fills fields.
  final GoalModel? goal;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  DateTime? _selectedDeadline;
  String _selectedIcon = _goalIcons.first;
  Color _selectedColor = _goalColors.first;
  String? _selectedWalletId;
  bool _isSubmitting = false;
  String? _nameError;
  String? _amountError;

  bool get _isEditMode => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _amountController = TextEditingController(
      text: goal != null
          ? NumberFormat.decimalPattern(
              'id_ID',
            ).format(goal.targetAmount.toInt())
          : '',
    );
    _selectedDeadline = goal?.deadline;
    _selectedIcon = goal?.icon ?? _goalIcons.first;
    _selectedColor = goal != null
        ? Color(int.parse(goal.color, radix: 16))
        : _goalColors.first;
    _selectedWalletId = goal?.linkedWalletId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        title: Text(
          _isEditMode ? 'goals.edit_title'.tr() : 'goals.create_title'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Name field
            _buildNameField(theme, isDark),
            const SizedBox(height: 20),

            // Target amount field
            _buildAmountField(theme, isDark),
            const SizedBox(height: 20),

            // Deadline picker
            _buildDeadlinePicker(theme, isDark),
            const SizedBox(height: 20),

            // Icon picker
            _buildIconPicker(theme, isDark),
            const SizedBox(height: 20),

            // Color picker
            _buildColorPicker(theme, isDark),
            const SizedBox(height: 20),

            // Wallet selector
            _buildWalletSelector(theme, isDark),
            const SizedBox(height: 12),

            // Warning for reducing target below current amount
            if (_isEditMode) _buildTargetWarning(theme),
            const SizedBox(height: 32),

            // Submit button
            _buildSubmitButton(theme),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Name Field ─────────────────────────────────────────────────────────────

  Widget _buildNameField(ThemeData theme, bool isDark) {
    return GlassInputField(
      controller: _nameController,
      labelText: 'goals.form_name'.tr(),
      hintText: 'goals.form_name_hint'.tr(),
      errorText: _nameError,
      onChanged: (_) {
        if (_nameError != null) setState(() => _nameError = null);
      },
    );
  }

  // ─── Amount Field ───────────────────────────────────────────────────────────

  Widget _buildAmountField(ThemeData theme, bool isDark) {
    return GlassInputField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsFormatter()],
      labelText: 'goals.form_target_amount'.tr(),
      errorText: _amountError,
      onChanged: (_) {
        if (_amountError != null) setState(() => _amountError = null);
      },
    );
  }

  // ─── Deadline Picker ────────────────────────────────────────────────────────

  Widget _buildDeadlinePicker(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'goals.form_deadline'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDeadline,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedDeadline != null
                        ? DateFormat('dd MMM yyyy').format(_selectedDeadline!)
                        : 'goals.detail_no_deadline'.tr(),
                    style: TextStyle(
                      color: _selectedDeadline != null
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_selectedDeadline != null)
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedDeadline = null);
                    },
                    child: Icon(
                      Icons.clear_rounded,
                      size: 20,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() => _selectedDeadline = picked);
    }
  }

  // ─── Icon Picker ────────────────────────────────────────────────────────────

  Widget _buildIconPicker(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'goals.form_icon'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _goalIcons.map((icon) {
              final isSelected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedIcon = icon);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 24)),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── Color Picker ───────────────────────────────────────────────────────────

  Widget _buildColorPicker(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'goals.form_color'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _goalColors.map((color) {
              final isSelected = color.toARGB32() == _selectedColor.toARGB32();
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedColor = color);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: isDark ? Colors.white : Colors.black87,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── Wallet Selector ────────────────────────────────────────────────────────

  Widget _buildWalletSelector(ThemeData theme, bool isDark) {
    final walletsAsync = ref.watch(walletProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'goals.form_wallet'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        walletsAsync.when(
          data: (wallets) => _buildWalletDropdown(wallets, theme, isDark),
          loading: () => Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (_, _) => Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              'Error loading wallets',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWalletDropdown(
    List<WalletModel> wallets,
    ThemeData theme,
    bool isDark,
  ) {
    // Filter wallets: exclude those already linked to active goals
    // But keep the currently linked wallet in edit mode
    final availableWallets = wallets.where((wallet) {
      if (_isEditMode && wallet.id == widget.goal?.linkedWalletId) {
        return true; // Keep the currently linked wallet in edit mode
      }
      return true; // We'll check linking status asynchronously below
    }).toList();

    return FutureBuilder<List<WalletModel>>(
      future: _filterUnlinkedWallets(availableWallets),
      builder: (context, snapshot) {
        final filteredWallets = snapshot.data ?? availableWallets;

        return DropdownButtonFormField<String?>(
          initialValue: _selectedWalletId,
          decoration: InputDecoration(
            hintText: 'goals.form_wallet_hint'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'goals.tracking_manual'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            ...filteredWallets.map((wallet) {
              return DropdownMenuItem<String?>(
                value: wallet.id,
                child: Text(
                  '${wallet.name} (${wallet.type})',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              );
            }),
          ],
          onChanged: (value) {
            setState(() => _selectedWalletId = value);
          },
        );
      },
    );
  }

  Future<List<WalletModel>> _filterUnlinkedWallets(
    List<WalletModel> wallets,
  ) async {
    final repository = ref.read(goalRepositoryProvider);
    final filtered = <WalletModel>[];

    for (final wallet in wallets) {
      // In edit mode, always include the currently linked wallet
      if (_isEditMode && wallet.id == widget.goal?.linkedWalletId) {
        filtered.add(wallet);
        continue;
      }

      final result = await repository.isWalletLinked(wallet.id);
      switch (result) {
        case Success(:final value):
          if (!value) {
            filtered.add(wallet);
          }
        case Failure():
          // On error, include the wallet (fail open)
          filtered.add(wallet);
      }
    }

    return filtered;
  }

  // ─── Target Warning ─────────────────────────────────────────────────────────

  Widget _buildTargetWarning(ThemeData theme) {
    final amountText = _amountController.text.trim();
    final newTarget = double.tryParse(amountText);
    final currentAmount = widget.goal?.currentAmount ?? 0.0;

    if (newTarget == null || newTarget >= currentAmount) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'goals.warning_reduce_target'.tr(),
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Submit Button ──────────────────────────────────────────────────────────

  Widget _buildSubmitButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: GlassButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        isLoading: _isSubmitting,
        child: Text(
          _isEditMode ? 'goals.save'.tr() : 'goals.create'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─── Submit Handler ─────────────────────────────────────────────────────────

  Future<void> _handleSubmit() async {
    // Manual validation since we're using GlassInputField
    bool hasError = false;
    setState(() {
      if (_nameController.text.trim().isEmpty) {
        _nameError = 'goals.validation_name_empty'.tr();
        hasError = true;
      } else if (_nameController.text.trim().length > 100) {
        _nameError = 'goals.validation_name_too_long'.tr();
        hasError = true;
      }

      if (_amountController.text.trim().isEmpty) {
        _amountError = 'goals.validation_amount_invalid'.tr();
        hasError = true;
      } else {
        final amount = ThousandsFormatter.parse(_amountController.text.trim());
        if (amount <= 0) {
          _amountError = 'goals.validation_amount_invalid'.tr();
          hasError = true;
        }
      }
    });

    if (hasError) return;

    // Additional deadline validation
    if (_selectedDeadline != null &&
        _selectedDeadline!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('goals.validation_deadline_past'.tr())),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final targetAmount = ThousandsFormatter.parse(
      _amountController.text.trim(),
    );
    final colorHex = _selectedColor
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0');

    final notifier = ref.read(goalNotifierProvider.notifier);

    if (_isEditMode) {
      // Update existing goal
      final updatedGoal = widget.goal!.copyWith(
        name: name,
        targetAmount: targetAmount,
        deadline: _selectedDeadline,
        clearDeadline: _selectedDeadline == null,
        icon: _selectedIcon,
        color: colorHex,
        linkedWalletId: _selectedWalletId,
        clearLinkedWalletId: _selectedWalletId == null,
        trackingMode: _selectedWalletId != null
            ? TrackingMode.wallet
            : TrackingMode.manual,
      );

      final result = await notifier.updateGoal(updatedGoal);
      _handleResult(result);
    } else {
      // Create new goal
      final result = await notifier.createGoal(
        name: name,
        targetAmount: targetAmount,
        deadline: _selectedDeadline,
        icon: _selectedIcon,
        color: colorHex,
        linkedWalletId: _selectedWalletId,
      );

      switch (result) {
        case Success():
          if (mounted) context.pop();
        case Failure(:final error):
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(error.message)));
          }
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _handleResult(Result<void, dynamic> result) {
    switch (result) {
      case Success():
        if (mounted) context.pop();
      case Failure(:final error):
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
    }
  }
}
