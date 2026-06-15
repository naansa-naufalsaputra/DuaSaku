import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../providers/wallet_provider.dart';
import '../../domain/models/wallet_model.dart';
import '../../../transactions/providers/transaction_provider.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/utils/category_translation.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';

class WalletDetailScreen extends ConsumerStatefulWidget {
  final String walletId;
  const WalletDetailScreen({super.key, required this.walletId});

  @override
  ConsumerState<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends ConsumerState<WalletDetailScreen> {
  String _selectedFilter = 'all'; // 'all', 'income', 'expense', 'transfer'

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

  @override
  Widget build(BuildContext context) {
    final walletsAsync = ref.watch(walletProvider);
    final transactionsAsync = ref.watch(transactionNotifierProvider);
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
                final wallet = wallets.firstWhere(
                  (w) => w.id == widget.walletId,
                  orElse: () => WalletModel(
                    id: '',
                    userId: '',
                    name: 'Unknown',
                    type: 'unknown',
                    balance: 0,
                    createdAt: DateTime.now(),
                  ),
                );

                if (wallet.id.isEmpty) {
                  return Center(
                    child: Text(
                      'Wallet not found',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }

                final gradientColors = _getGradientForType(wallet.type);

                return Column(
                  children: [
                    // Custom App Bar
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
                          Expanded(
                            child: Text(
                              wallet.name,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Scrollable Area wrapped in RepaintBoundary for animation performance optimization
                    Expanded(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          // Large Wallet Card
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Hero(
                                tag: 'wallet_card_${wallet.id}',
                                child: Container(
                                  height: 180,
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    gradient: LinearGradient(
                                      colors: gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradientColors[1].withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 15,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            wallet.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _getIconForType(wallet.type),
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  wallet.type.toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const Text(
                                        'BALANCE',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency.format(wallet.balance),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Transaction Filters Header
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'history.title'.tr(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Horizontal Filter Buttons
                          SliverToBoxAdapter(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    context,
                                    'all',
                                    'history.filter_all'.tr(),
                                  ),
                                  _buildFilterChip(
                                    context,
                                    'income',
                                    'history.income'.tr(),
                                  ),
                                  _buildFilterChip(
                                    context,
                                    'expense',
                                    'history.expense'.tr(),
                                  ),
                                  _buildFilterChip(
                                    context,
                                    'transfer',
                                    'history.transfer'.tr(),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Transaction List
                          transactionsAsync.when(
                            data: (allTransactions) {
                              // Filter transactions belonging to this wallet
                              final walletTransactions = allTransactions.where((
                                tx,
                              ) {
                                return tx.walletId == wallet.id ||
                                    tx.fromWalletId == wallet.id ||
                                    tx.toWalletId == wallet.id;
                              }).toList();

                              // Apply type filter
                              final filteredTransactions = walletTransactions
                                  .where((tx) {
                                    if (_selectedFilter == 'all') return true;
                                    return tx.type.toLowerCase() ==
                                        _selectedFilter.toLowerCase();
                                  })
                                  .toList();

                              if (filteredTransactions.isEmpty) {
                                return SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.history_toggle_off_rounded,
                                            size: 48,
                                            color: isDark
                                                ? Colors.white30
                                                : Colors.black38,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'home.no_transactions'.tr(),
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.white54
                                                  : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final tx = filteredTransactions[index];
                                  final isExpense =
                                      tx.type.toLowerCase() == 'expense';
                                  final isTransfer =
                                      tx.type.toLowerCase() == 'transfer';

                                  Color iconBg;
                                  Color iconColor;
                                  IconData icon;

                                  if (isTransfer) {
                                    iconBg = Colors.blue.withValues(alpha: 0.1);
                                    iconColor = Colors.blueAccent;
                                    icon = Icons.swap_horiz_rounded;
                                  } else if (isExpense) {
                                    iconBg = Colors.orange.withValues(
                                      alpha: 0.1,
                                    );
                                    iconColor = Colors.orangeAccent;
                                    icon = Icons.shopping_bag_outlined;
                                  } else {
                                    iconBg = Colors.green.withValues(
                                      alpha: 0.1,
                                    );
                                    iconColor = Colors.greenAccent;
                                    icon =
                                        Icons.account_balance_wallet_outlined;
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    child: GlassCard(
                                      onTap: () {},
                                      enableBlur: false,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(
                                                  alpha: 0.03,
                                                )
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withValues(
                                                    alpha: 0.02,
                                                  )
                                                : Colors.grey.withValues(
                                                    alpha: 0.1,
                                                  ),
                                          ),
                                          boxShadow: isDark
                                              ? null
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: 0.05,
                                                        ),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: iconBg,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Icon(
                                                icon,
                                                color: iconColor,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    tx.notes.isNotEmpty
                                                        ? tx.notes
                                                        : tx.category
                                                              .toLocalizedCategory(),
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white
                                                          : Colors.black87,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    tx.category
                                                        .toLocalizedCategory()
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                      color: isDark
                                                          ? Colors.white54
                                                          : Colors.black54,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      letterSpacing: 1,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${isExpense ? '-' : (isTransfer ? '' : '+')}${formatCurrency.format(tx.amount)}',
                                                  style: TextStyle(
                                                    color: isTransfer
                                                        ? (isDark
                                                              ? Colors.white
                                                              : Colors.black87)
                                                        : (isExpense
                                                              ? (isDark
                                                                    ? Colors
                                                                          .white
                                                                    : Colors
                                                                          .black87)
                                                              : Colors
                                                                    .greenAccent),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  DateFormat(
                                                    'dd MMM yyyy',
                                                  ).format(tx.createdAt),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white30
                                                        : Colors.black38,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ).liquidStagger(index);
                                }, childCount: filteredTransactions.length),
                              );
                            },
                            loading: () => const SliverFillRemaining(
                              child: Center(child: CircularProgressIndicator()),
                            ),
                            error: (err, _) => SliverFillRemaining(
                              child: Center(
                                child: Text(
                                  'Error: $err',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 32)),
                        ],
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String filterType,
    String label,
  ) {
    final isSelected = _selectedFilter == filterType;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedFilter = filterType;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.15)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03)),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05)),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
