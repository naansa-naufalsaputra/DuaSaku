import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/wallet_provider.dart';
import '../../domain/models/wallet_model.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../../../../core/utils/thousands_formatter.dart';

class ManageWalletsScreen extends ConsumerStatefulWidget {
  const ManageWalletsScreen({super.key});

  @override
  ConsumerState<ManageWalletsScreen> createState() =>
      _ManageWalletsScreenState();
}

class _ManageWalletsScreenState extends ConsumerState<ManageWalletsScreen> {
  int? _selectedWalletIndex;

  // Custom colors for premium cards based on wallet type
  List<Color> _getGradientForType(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'bank':
        return [
          const Color(0xFF3B82F6),
          const Color(0xFF1D4ED8),
        ]; // Indigo/Blue
      case 'e-wallet':
        return [
          const Color(0xFF8B5CF6),
          const Color(0xFF6D28D9),
        ]; // Purple/Pink
      case 'cash':
        return [
          const Color(0xFF10B981),
          const Color(0xFF047857),
        ]; // Emerald/Teal
      default:
        return [const Color(0xFF6366F1), const Color(0xFF4338CA)];
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return Icons.account_balance_rounded;
      case 'e-wallet':
        return Icons.account_balance_wallet_rounded;
      case 'cash':
        return Icons.payments_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

  void _showWalletFormBottomSheet({WalletModel? walletToEdit}) {
    final nameController = TextEditingController(
      text: walletToEdit?.name ?? '',
    );
    final balanceController = TextEditingController(
      text: walletToEdit != null ? walletToEdit.balance.toInt().toString() : '',
    );
    String walletType = walletToEdit?.type ?? 'Bank';
    String? nameError;
    String? balanceError;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    Text(
                      walletToEdit == null
                          ? 'wallets.title_add_new'.tr()
                          : 'wallets.title_edit'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Name Field
                    GlassInputField(
                      controller: nameController,
                      labelText: 'wallets.field_name_hint'.tr(),
                      errorText: nameError,
                      onChanged: (_) {
                        if (nameError != null) {
                          setModalState(() => nameError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Wallet Type selector label
                    Text(
                      'wallets.field_type'.tr(),
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Horizontal Choice Card Selector for Wallet Type
                    Row(
                      children: ['Bank', 'E-Wallet', 'Cash'].map((type) {
                        final isSelected =
                            walletType.toLowerCase() == type.toLowerCase();
                        final icon = _getIconForType(type);

                        Color accentColor;
                        switch (type.toLowerCase()) {
                          case 'bank':
                            accentColor = const Color(0xFF3B82F6);
                            break;
                          case 'e-wallet':
                            accentColor = const Color(0xFF8B5CF6);
                            break;
                          default:
                            accentColor = const Color(0xFF10B981);
                        }

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setModalState(() => walletType = type);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? accentColor
                                      : Colors.grey.withValues(alpha: 0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    icon,
                                    color: isSelected
                                        ? accentColor
                                        : (isDark
                                              ? Colors.white54
                                              : Colors.black45),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'wallets.type_${type.toLowerCase().replaceAll('-', '')}'
                                        .tr(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? accentColor
                                          : (isDark
                                                ? Colors.white70
                                                : Colors.black87),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // Balance Input Field
                    GlassInputField(
                      controller: balanceController,
                      labelText: 'wallets.field_balance'.tr(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsFormatter()],
                      errorText: balanceError,
                      onChanged: (_) {
                        if (balanceError != null) {
                          setModalState(() => balanceError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    GlassButton(
                      onPressed: () async {
                        bool hasError = false;
                        setModalState(() {
                          nameError = nameController.text.isEmpty
                              ? 'wallets.error_required'.tr()
                              : null;
                          balanceError = balanceController.text.isEmpty
                              ? 'wallets.error_required'.tr()
                              : null;
                          hasError = nameError != null || balanceError != null;
                        });

                        if (!hasError) {
                          final walletName = nameController.text;
                          final initialBalance = ThousandsFormatter.parse(
                            balanceController.text,
                          );
                          final notifier = ref.read(walletProvider.notifier);
                          final navigator = Navigator.of(ctx);

                          try {
                            if (walletToEdit == null) {
                              await notifier.addWallet(
                                name: walletName,
                                type: walletType,
                                initialBalance: initialBalance,
                              );
                            } else {
                              final updated = WalletModel(
                                id: walletToEdit.id,
                                userId: walletToEdit.userId,
                                name: walletName,
                                type: walletType,
                                balance: initialBalance,
                                createdAt: walletToEdit.createdAt,
                              );
                              await notifier.updateWallet(updated);
                            }
                            HapticFeedback.mediumImpact();
                            navigator.pop();
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: Text(
                        walletToEdit == null
                            ? 'wallets.btn_create'.tr()
                            : 'wallets.btn_save'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletProvider);
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: walletsAsync.when(
              data: (wallets) {
                final totalBalance = wallets.fold(
                  0.0,
                  (sum, w) => sum + w.balance,
                );

                return Column(
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.pop();
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'wallets.title_manage'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content Area
                    Expanded(
                      child: wallets.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurpleAccent
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet_outlined,
                                        size: 64,
                                        color: Colors.deepPurpleAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'wallets.empty_state_title'.tr(),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'wallets.empty_state_desc'.tr(),
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 32),
                                    GlassButton(
                                      onPressed: () =>
                                          _showWalletFormBottomSheet(),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'wallets.btn_add_wallet'.tr(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                // 1. Total Balance Card (Animate scale and fade entry)
                                Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(28),
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6366F1),
                                            Color(0xFF4F46E5),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF6366F1,
                                            ).withValues(alpha: 0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'wallets.label_total_balance'.tr(),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          AnimatedCountText(
                                            value: totalBalance,
                                            formatter: formatCurrency,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fade(duration: 500.ms)
                                    .slideY(
                                      begin: -0.15,
                                      end: 0.0,
                                      curve: Curves.easeOutCubic,
                                    ),
                                const SizedBox(height: 24),

                                // 2. Wallet List in stacked card layout
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: wallets.length,
                                  itemBuilder: (context, index) {
                                    final wallet = wallets[index];
                                    final isSelected =
                                        _selectedWalletIndex == index;
                                    final colors = _getGradientForType(
                                      wallet.type,
                                      isDark,
                                    );

                                    return AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      curve:
                                          Curves.easeOutBack, // Bouncy bounce
                                      heightFactor: isSelected ? 1.0 : 0.58,
                                      alignment: Alignment.topCenter,
                                      child: InteractivePressFeedback(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            if (isSelected) {
                                              _selectedWalletIndex = null;
                                            } else {
                                              _selectedWalletIndex = index;
                                            }
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 400,
                                          ),
                                          curve: Curves
                                              .easeOutBack, // Bouncy height transition
                                          width: double.infinity,
                                          height: isSelected ? 220 : 130,
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            gradient: LinearGradient(
                                              colors: colors,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colors[1].withValues(
                                                  alpha: isSelected
                                                      ? 0.35
                                                      : 0.15,
                                                ),
                                                blurRadius: isSelected ? 15 : 6,
                                                offset: Offset(
                                                  0,
                                                  isSelected ? 8 : 4,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    wallet.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          _getIconForType(
                                                            wallet.type,
                                                          ),
                                                          color: Colors.white,
                                                          size: 14,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          'wallets.type_${wallet.type.toLowerCase().replaceAll('-', '')}'
                                                              .tr(),
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Text(
                                                formatCurrency.format(
                                                  wallet.balance,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),

                                              // Actions Panel: Animated height clip & opacity fade
                                              AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 250,
                                                ),
                                                opacity: isSelected ? 1.0 : 0.0,
                                                child: ClipRect(
                                                  child: AnimatedAlign(
                                                    duration: const Duration(
                                                      milliseconds: 300,
                                                    ),
                                                    curve: Curves.easeOutBack,
                                                    heightFactor: isSelected
                                                        ? 1.0
                                                        : 0.0,
                                                    alignment:
                                                        Alignment.topCenter,
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const SizedBox(
                                                          height: 16,
                                                        ),
                                                        const Divider(
                                                          color: Colors.white24,
                                                          height: 1,
                                                        ),
                                                        const SizedBox(
                                                          height: 12,
                                                        ),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          children: [
                                                            // Edit button
                                                            InteractivePressFeedback(
                                                              onTap: () {
                                                                HapticFeedback.lightImpact();
                                                                _showWalletFormBottomSheet(
                                                                  walletToEdit:
                                                                      wallet,
                                                                );
                                                              },
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16,
                                                                      vertical:
                                                                          8,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.15,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .edit_rounded,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 18,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      'wallets.btn_edit'
                                                                          .tr(),
                                                                      style: const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 12,
                                                            ),
                                                            // Delete button
                                                            InteractivePressFeedback(
                                                              onTap: () async {
                                                                HapticFeedback.vibrate();
                                                                final confirmed = await showDialog<bool>(
                                                                  context:
                                                                      context,
                                                                  builder: (ctx) => AlertDialog(
                                                                    title: Text(
                                                                      'wallets.dialog_delete_title'
                                                                          .tr(),
                                                                    ),
                                                                    content: Text(
                                                                      'wallets.dialog_delete_message'.tr(
                                                                        args: [
                                                                          wallet
                                                                              .name,
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    actions: [
                                                                      GlassButton(
                                                                        variant:
                                                                            GlassButtonVariant.text,
                                                                        onPressed: () => Navigator.pop(
                                                                          ctx,
                                                                          false,
                                                                        ),
                                                                        child: Text(
                                                                          'wallets.dialog_delete_cancel'
                                                                              .tr(),
                                                                        ),
                                                                      ),
                                                                      GlassButton(
                                                                        onPressed: () => Navigator.pop(
                                                                          ctx,
                                                                          true,
                                                                        ),
                                                                        child: Text(
                                                                          'wallets.dialog_delete_confirm'
                                                                              .tr(),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                                if (confirmed ==
                                                                        true &&
                                                                    context
                                                                        .mounted) {
                                                                  await ref
                                                                      .read(
                                                                        walletProvider
                                                                            .notifier,
                                                                      )
                                                                      .deleteWallet(
                                                                        wallet
                                                                            .id,
                                                                      );
                                                                  setState(
                                                                    () =>
                                                                        _selectedWalletIndex =
                                                                            null,
                                                                  );
                                                                }
                                                              },
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16,
                                                                      vertical:
                                                                          8,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .white
                                                                      .withValues(
                                                                        alpha:
                                                                            0.15,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    const Icon(
                                                                      Icons
                                                                          .delete_rounded,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 18,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      'wallets.btn_delete'
                                                                          .tr(),
                                                                      style: const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ).liquidStagger(index);
                                  },
                                ),
                                // Bottom padding for stacked card list
                                const SizedBox(height: 100),
                              ],
                            ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
      // Hide FAB conditionally if the wallet list is empty
      floatingActionButton: Consumer(
        builder: (context, ref, child) {
          final wallets = ref.watch(walletProvider).valueOrNull ?? [];
          if (wallets.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showWalletFormBottomSheet(),
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'wallets.btn_add_wallet'.tr(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.deepPurpleAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}

// Custom animated count text to count-up balance smoothly
class AnimatedCountText extends StatefulWidget {
  final double value;
  final TextStyle style;
  final NumberFormat formatter;

  const AnimatedCountText({
    super.key,
    required this.value,
    required this.style,
    required this.formatter,
  });

  @override
  State<AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<AnimatedCountText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _controller.reset();
      _animation = Tween<double>(begin: _oldValue, end: widget.value).animate(
        CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          widget.formatter.format(_animation.value),
          style: widget.style,
        );
      },
    );
  }
}

// Custom tactile press/scale feedback wrapper
class InteractivePressFeedback extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const InteractivePressFeedback({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<InteractivePressFeedback> createState() =>
      _InteractivePressFeedbackState();
}

class _InteractivePressFeedbackState extends State<InteractivePressFeedback> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutQuad,
        child: widget.child,
      ),
    );
  }
}
