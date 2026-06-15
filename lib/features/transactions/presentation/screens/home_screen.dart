import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/service_providers.dart';
import '../../../profile/providers/display_name_provider.dart';
import '../../../../core/utils/text_sanitizer.dart';

import '../../../../core/widgets/glass/glass_button.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../domain/models/category_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../../domain/models/transaction_model.dart';
import '../widgets/transaction_type_bottom_sheet.dart';
import '../widgets/transaction_draft_bottom_sheet.dart';
import '../widgets/transaction_detail_dialog.dart';
import '../../../../core/utils/category_translation.dart';
import '../../../../main.dart';
import '../../../recurring_transactions/presentation/widgets/upcoming_recurring_dashboard_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isProcessingAI = false;
  bool _isProcessingReceipt = false;
  final _homeSmartInputController = TextEditingController();

  void _showScanSourceDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassCard(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF161515).withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'home.scan_receipt_title'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _scanReceipt(ImageSource.camera);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            const Icon(Icons.camera_alt_rounded, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'home.scan_from_camera'.tr(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _scanReceipt(ImageSource.gallery);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          children: [
                            const Icon(Icons.photo_library_rounded, size: 28),
                            const SizedBox(height: 8),
                            Text(
                              'home.scan_from_gallery'.tr(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanReceipt(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    XFile? image;
    try {
      image = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('[HomeScreen] Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('home.image_pick_failed'.tr(args: [e.toString()])),
          ),
        );
      }
      return;
    }

    if (image == null) return;

    setState(() => _isProcessingReceipt = true);
    HapticFeedback.mediumImpact();

    try {
      final draft = await ref
          .read(receiptScannerServiceProvider)
          .scanReceipt(image.path);
      if (mounted) {
        HapticFeedback.mediumImpact();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => TransactionDraftBottomSheet(draftData: draft),
        );
      }
    } catch (e) {
      debugPrint('[HomeScreen] Error processing receipt scanner: $e');
      if (mounted) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'home.receipt_process_failed'.tr(args: [e.toString()]),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingReceipt = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // One-time check on mount to see if the app was launched by tapping the home widget
    Future.microtask(() {
      if (mounted) {
        final shouldLaunch = ref.read(widgetLaunchProvider);
        if (shouldLaunch) {
          ref.read(widgetLaunchProvider.notifier).state = false;
          _showTransactionBottomSheet();
        }
      }
    });
  }

  @override
  void dispose() {
    _homeSmartInputController.dispose();
    super.dispose();
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'home.greeting_morning'.tr();
    if (hour < 17) return 'home.greeting_afternoon'.tr();
    return 'home.greeting_evening'.tr();
  }

  double _calculateMonthlyCashflow(List<TransactionModel> txs, String type) {
    final now = DateTime.now();
    double total = 0;
    for (var tx in txs) {
      if (tx.createdAt.month == now.month && tx.createdAt.year == now.year) {
        if (tx.type.toLowerCase() == type.toLowerCase()) total += tx.amount;
      }
    }
    return total;
  }

  Future<void> _submitHomeSmartInput(String text) async {
    if (text.trim().isEmpty) {
      HapticFeedback.vibrate();
      return;
    }
    setState(() => _isProcessingAI = true);
    try {
      final draft = await ref
          .read(transactionNotifierProvider.notifier)
          .parseSmartText(text);
      if (mounted) {
        HapticFeedback.mediumImpact();
        _homeSmartInputController.clear();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => TransactionDraftBottomSheet(draftData: draft),
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
    }
  }

  IconData _getCategoryIconData(String? name, bool isExpense) {
    switch (name?.toLowerCase()) {
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
        return isExpense
            ? Icons.shopping_bag_outlined
            : Icons.account_balance_wallet_outlined;
    }
  }

  void _showTransactionBottomSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TransactionTypeBottomSheet(),
    );
  }

  Widget _buildWalletTiltedStack(WidgetRef ref, ThemeData theme, bool isDark) {
    final walletsAsync = ref.watch(walletProvider);
    final txAsync = ref.watch(transactionNotifierProvider);

    return walletsAsync.when(
      data: (wallets) {
        if (wallets.isEmpty) return const SizedBox.shrink();

        final txs = txAsync.valueOrNull ?? [];
        final monthlyInc = _calculateMonthlyCashflow(txs, 'income');
        final monthlyExp = _calculateMonthlyCashflow(txs, 'expense');

        return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'home.my_wallets'.tr(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _WalletStackedLayout(
                      wallets: wallets,
                      isDark: isDark,
                      monthlyIncome: monthlyInc,
                      monthlyExpense: monthlyExp,
                    ),
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 500.ms, delay: 120.ms)
            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActionRow(ThemeData theme, bool isDark) {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickPill(
                  label: 'home.action_top_up'.tr(),
                  onTap: _showTransactionBottomSheet,
                  theme: theme,
                  isDark: isDark,
                  isActive: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickPill(
                  label: 'home.action_transfer'.tr(),
                  onTap: _showTransactionBottomSheet,
                  theme: theme,
                  isDark: isDark,
                  isActive: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickPill(
                  label: 'home.action_scan_qr'.tr(),
                  onTap: _showScanSourceDialog,
                  theme: theme,
                  isDark: isDark,
                  isActive: false,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 120.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildQuickPill({
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    required bool isActive,
  }) {
    final activeColor = isDark
        ? const Color(0xFF0A84FF)
        : const Color(0xFF007AFF);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final textColor = isActive
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          color: isActive ? activeColor : inactiveColor,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<_HomeFeedItem> _buildFeedItems(List<TransactionModel> transactions) {
    final recentTxs = transactions.take(10).toList();
    final Map<DateTime, List<TransactionModel>> grouped = {};
    for (final tx in recentTxs) {
      final dateOnly = DateTime(
        tx.createdAt.year,
        tx.createdAt.month,
        tx.createdAt.day,
      );
      grouped.putIfAbsent(dateOnly, () => []).add(tx);
    }

    final items = <_HomeFeedItem>[];
    int staggerIndex = 0;

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final date in sortedDates) {
      final txsForDate = grouped[date]!;
      double netChange = 0;
      for (final tx in txsForDate) {
        if (tx.type.toLowerCase() == 'expense') {
          netChange -= tx.amount;
        } else if (tx.type.toLowerCase() == 'income') {
          netChange += tx.amount;
        }
      }
      items.add(_DateHeaderItem(date, netChange));
      for (final tx in txsForDate) {
        items.add(_TransactionFeedItem(tx, staggerIndex++));
      }
    }
    return items;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) {
      return 'home.today'.tr();
    } else if (date == yesterday) {
      return 'home.yesterday'.tr();
    } else {
      return DateFormat('dd MMMM yyyy').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = ref.watch(userProvider);
    final txAsync = ref.watch(transactionNotifierProvider);
    final walletsAsync = ref.watch(walletProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    // Listen for widget clicks while the app is actively running in memory
    ref.listen<bool>(widgetLaunchProvider, (previous, next) {
      if (next) {
        ref.read(widgetLaunchProvider.notifier).state = false;
        Future.microtask(() {
          _showTransactionBottomSheet();
        });
      }
    });
    final displayName = ref.watch(displayNameProvider);
    final String userName = displayName.isNotEmpty
        ? displayName
        : (user?.email != null && user!.email.contains('@')
              ? user.email.split('@').first
              : 'User');
    final String initial = userName.isNotEmpty
        ? userName[0].toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Premium Background with Glassmorphism
          const PremiumBackground(),

          // 2. Main Scroll Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(transactionNotifierProvider.notifier)
                  .loadTransactions(),
              color: theme.colorScheme.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  // --- HEADER ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isDark
                                    ? const Color(
                                        0xFF0A84FF,
                                      ).withValues(alpha: 0.1)
                                    : const Color(
                                        0xFF007AFF,
                                      ).withValues(alpha: 0.1),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF0A84FF)
                                        : const Color(0xFF007AFF),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getTimeOfDay(),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : Colors.black54,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    userName,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none_rounded,
                              size: 24,
                            ),
                            color: isDark ? Colors.white70 : Colors.black87,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- QUICK ACTIONS ROW ---
                  SliverToBoxAdapter(
                    child: _buildQuickActionRow(theme, isDark),
                  ),

                  // --- WALLET TILTED STACK ---
                  SliverToBoxAdapter(
                    child: _buildWalletTiltedStack(ref, theme, isDark),
                  ),

                  // --- SAVINGS GOALS ENTRY ---
                  SliverToBoxAdapter(
                    child:
                        Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                              child: GlassCard(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context.push('/goals');
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? const [
                                              Color(0x1F10B981),
                                              Color(0x0F0F172A),
                                            ]
                                          : [
                                              Colors.green.withValues(
                                                alpha: 0.06,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.95,
                                              ),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : Colors.green.withValues(
                                              alpha: 0.15,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.savings_rounded,
                                          color: Colors.green,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'goals.title'.tr(),
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'goals.home_subtitle'.tr(),
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white54
                                                    : Colors.black45,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(duration: 400.ms, delay: 300.ms)
                            .slideY(
                              begin: 0.1,
                              end: 0,
                              curve: Curves.easeOutQuad,
                            ),
                  ),

                  // --- TRANSACTIONS LIST HEADER ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.history,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'home.recent_transactions'.tr(),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          GlassButton(
                            variant: GlassButtonVariant.text,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.push('/history');
                            },
                            child: Text(
                              'home.see_all'.tr(),
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  ),

                  // --- TRANSACTIONS LIST ---
                  txAsync.when(
                    data: (transactions) {
                      if (transactions.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'home.no_transactions'.tr(),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(),
                        );
                      }

                      final feedItems = _buildFeedItems(transactions);

                      return SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = feedItems[index];

                          if (item is _DateHeaderItem) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDateHeader(item.date),
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    item.netChange > 0
                                        ? '+${formatCurrency.format(item.netChange)}'
                                        : item.netChange < 0
                                        ? '-${formatCurrency.format(item.netChange.abs())}'
                                        : formatCurrency.format(0),
                                    style: TextStyle(
                                      color: item.netChange > 0
                                          ? Colors.greenAccent
                                          : (isDark
                                                ? Colors.white70
                                                : Colors.black87),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final txItem = item as _TransactionFeedItem;
                          final tx = txItem.transaction;
                          final isExpense = tx.type.toLowerCase() == 'expense';

                          final matchedCategory = categories.firstWhere(
                            (c) =>
                                c.name.toLowerCase() ==
                                tx.category.toLowerCase(),
                            orElse: () => CategoryModel(
                              id: '',
                              userId: '',
                              name: tx.category,
                              type: tx.type,
                              icon: isExpense ? 'restaurant' : 'attach_money',
                              color: isExpense ? '#F43F5E' : '#10B981',
                              createdAt: DateTime.now(),
                            ),
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                InkWell(
                                  onTap: () {},
                                  onLongPress: () {
                                    TransactionDetailDialog.show(
                                      context,
                                      transaction: tx,
                                      category: matchedCategory,
                                      wallets: walletsAsync.valueOrNull ?? [],
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(
                                                    0xFF0A84FF,
                                                  ).withValues(alpha: 0.08)
                                                : const Color(
                                                    0xFF007AFF,
                                                  ).withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getCategoryIconData(
                                              matchedCategory.icon,
                                              isExpense,
                                            ),
                                            color: isDark
                                                ? const Color(0xFF0A84FF)
                                                : const Color(0xFF007AFF),
                                            size: 20,
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
                                                    ? TextSanitizer.prettifyNotes(
                                                        tx.notes,
                                                      )
                                                    : tx.category
                                                          .toLocalizedCategory(),
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                tx.category
                                                    .toLocalizedCategory()
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  color: isDark
                                                      ? Colors.white30
                                                      : Colors.black38,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w300,
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
                                              '${isExpense ? '-' : '+'}${formatCurrency.format(tx.amount)}',
                                              style: TextStyle(
                                                color: isExpense
                                                    ? (isDark
                                                          ? Colors.white
                                                          : Colors.black87)
                                                    : const Color(0xFF10B981),
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat(
                                                'HH:mm',
                                              ).format(tx.createdAt),
                                              style: TextStyle(
                                                color: isDark
                                                    ? Colors.white30
                                                    : Colors.black38,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w300,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (index < feedItems.length - 1 &&
                                    feedItems[index + 1] is! _DateHeaderItem)
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05),
                                  ),
                              ],
                            ),
                          ).liquidStagger(txItem.index);
                        }, childCount: feedItems.length),
                      );
                    },
                    loading: () => SliverToBoxAdapter(
                      child: Column(
                        children: List.generate(
                          3,
                          (index) =>
                              Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 8,
                                    ),
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  )
                                  .animate(
                                    onPlay: (controller) => controller.repeat(),
                                  )
                                  .shimmer(
                                    duration: 1200.ms,
                                    color: Colors.white10,
                                  ),
                        ),
                      ),
                    ),
                    error: (error, _) => SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'Error: $error',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ),

                  // --- UPCOMING RECURRING TRANSACTIONS ---
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: UpcomingRecurringDashboardWidget(),
                    ),
                  ),

                  // Bottom padding for floating smart input bar
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          // Floating Smart Input Bar
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: isDark
                            ? const Color(0xFF0A84FF)
                            : const Color(0xFF007AFF),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _homeSmartInputController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'home.smart_input_placeholder'.tr(),
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black38,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onEditingComplete: _isProcessingAI
                              ? null
                              : () => _submitHomeSmartInput(
                                  _homeSmartInputController.text,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.mic_none_rounded),
                        color: isDark ? Colors.white54 : Colors.black54,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: _isProcessingAI
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark
                                      ? const Color(0xFF0A84FF)
                                      : const Color(0xFF007AFF),
                                ),
                              )
                            : Icon(
                                Icons.send_rounded,
                                color: isDark
                                    ? const Color(0xFF0A84FF)
                                    : const Color(0xFF007AFF),
                              ),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _isProcessingAI || _isProcessingReceipt
                            ? null
                            : () => _submitHomeSmartInput(
                                _homeSmartInputController.text,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_isProcessingReceipt)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withValues(
                      alpha: 0.4,
                    ),
                    child: Center(
                      child: GlassCard(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 24,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'home.processing_receipt'.tr(),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
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
}

/// A horizontal tilted/stacked wallet card view using PageView.
/// Cards appear tilted and stacked like a deck, with the active card centered.
class _WalletStackedLayout extends StatefulWidget {
  final List wallets;
  final bool isDark;
  final double monthlyIncome;
  final double monthlyExpense;

  const _WalletStackedLayout({
    required this.wallets,
    required this.isDark,
    required this.monthlyIncome,
    required this.monthlyExpense,
  });

  @override
  State<_WalletStackedLayout> createState() => _WalletStackedLayoutState();
}

class _WalletStackedLayoutState extends State<_WalletStackedLayout>
    with TickerProviderStateMixin {
  late final AnimationController _openController;
  late final AnimationController _expansionController;
  int? _animatingIndex;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _openController.dispose();
    _expansionController.dispose();
    super.dispose();
  }

  List<Color> _getGradientForType(String type) {
    switch (type.toLowerCase()) {
      case 'bank':
        return const [Color(0xFF0056B3), Color(0xFF007AFF)];
      case 'e-wallet':
        return const [Color(0xFF475569), Color(0xFF64748B)];
      case 'cash':
        return const [Color(0xFF1E293B), Color(0xFF334155)];
      default:
        return const [Color(0xFF334155), Color(0xFF475569)];
    }
  }

  String _formatAbbreviated(double amount) {
    if (amount >= 1000000) {
      final val = amount / 1000000.0;
      final valStr = val == val.toInt()
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      return 'Rp ${valStr}M';
    } else if (amount >= 1000) {
      final val = amount / 1000.0;
      final valStr = val == val.toInt()
          ? val.toInt().toString()
          : val.toStringAsFixed(1);
      return 'Rp ${valStr}k';
    } else {
      return 'Rp ${amount.toStringAsFixed(0)}';
    }
  }

  void _handleCardTap(int index, String walletId) {
    if (_animatingIndex != null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _animatingIndex = index;
    });
    _openController.forward().then((_) {
      if (mounted) {
        context.push('/wallets/$walletId').then((_) {
          if (mounted) {
            _openController.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _animatingIndex = null;
                });
              }
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final L = widget.wallets.length;

    const double cardHeight = 125.0;
    final double totalBalance = widget.wallets.fold(
      0.0,
      (sum, w) => sum + w.balance,
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_openController, _expansionController]),
      builder: (context, child) {
        final double animatedStep = 40.0 + (_expansionController.value * 80.0);
        final double totalHeight = cardHeight + (L * animatedStep) + 10.0;

        final double expansionProgress = _expansionController.value;
        final double scaleFactor = 0.035 - (expansionProgress * 0.02);

        return RepaintBoundary(
          child: SizedBox(
            height: totalHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_animatingIndex != null) return;
                HapticFeedback.lightImpact();
                if (_expansionController.isAnimating) return;
                if (_expansionController.value > 0.5) {
                  _expansionController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                  );
                } else {
                  _expansionController.animateTo(
                    1.0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                  );
                }
              },
              onVerticalDragUpdate: (details) {
                if (_animatingIndex != null) return;
                final double delta = -details.delta.dy / 150.0;
                _expansionController.value =
                    (_expansionController.value + delta).clamp(0.0, 1.0);
              },
              onVerticalDragEnd: (details) {
                if (_animatingIndex != null) return;
                final double velocity = details.primaryVelocity ?? 0.0;
                if (velocity < -300) {
                  _expansionController.animateTo(
                    1.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                } else if (velocity > 300) {
                  _expansionController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                } else {
                  if (_expansionController.value >= 0.5) {
                    _expansionController.animateTo(
                      1.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                    );
                  } else {
                    _expansionController.animateTo(
                      0.0,
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                    );
                  }
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...List.generate(L, (index) {
                    final wallet = widget.wallets[index];
                    final isTarget = _animatingIndex == index;
                    final isAnyTarget = _animatingIndex != null;

                    final int reversePos = L - index;
                    final double normalOffsetY = -reversePos * animatedStep;
                    final double normalScale = 1.0 - (reversePos * scaleFactor);
                    final double normalOpacity = 0.7 + (index / L) * 0.3;

                    double offsetY = normalOffsetY;
                    double scale = normalScale;
                    double opacity = normalOpacity;

                    if (isTarget) {
                      offsetY =
                          normalOffsetY + (_openController.value * -130.0);
                      scale =
                          normalScale +
                          (_openController.value * (1.05 - normalScale));
                      opacity =
                          normalOpacity +
                          (_openController.value * (1.0 - normalOpacity));
                    } else if (isAnyTarget) {
                      opacity =
                          normalOpacity * (1.0 - _openController.value * 0.6);
                    }

                    final gradient = _getGradientForType(wallet.type);

                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Transform.translate(
                        offset: Offset(0, offsetY),
                        child: Transform.scale(
                          scale: scale,
                          alignment: Alignment.bottomCenter,
                          child: Opacity(
                            opacity: opacity.clamp(0.0, 1.0),
                            child: GestureDetector(
                              onTap: () => _handleCardTap(index, wallet.id),
                              child: Hero(
                                tag: 'wallet_card_${wallet.id}',
                                child: Container(
                                  height: cardHeight,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradient.first.withValues(
                                          alpha: isTarget ? 0.4 : 0.15,
                                        ),
                                        blurRadius: isTarget ? 16 : 8,
                                        offset: Offset(0, isTarget ? 8 : 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: gradient,
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 16,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      wallet.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    formatCurrency.format(
                                                      wallet.balance,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.2,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      wallet.type.toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Opacity(
                      opacity: (_animatingIndex != null)
                          ? (1.0 - _openController.value * 0.6).clamp(0.4, 1.0)
                          : 1.0,
                      child: Container(
                        height: cardHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF007AFF,
                              ).withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: widget.isDark
                                          ? const [
                                              Color(0xFF0A2F7A),
                                              Color(0xFF0A84FF),
                                            ]
                                          : const [
                                              Color(0xFF007AFF),
                                              Color(0xFF0A84FF),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'home.total_balance_label'
                                              .tr()
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      formatCurrency.format(totalBalance),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'IN +${_formatAbbreviated(widget.monthlyIncome)}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'OUT -${_formatAbbreviated(widget.monthlyExpense)}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

abstract class _HomeFeedItem {}

class _DateHeaderItem extends _HomeFeedItem {
  final DateTime date;
  final double netChange;
  _DateHeaderItem(this.date, this.netChange);
}

class _TransactionFeedItem extends _HomeFeedItem {
  final TransactionModel transaction;
  final int index;
  _TransactionFeedItem(this.transaction, this.index);
}
