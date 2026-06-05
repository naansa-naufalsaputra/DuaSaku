import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../services/service_providers.dart';
import '../../../profile/providers/display_name_provider.dart';

import '../../../../core/widgets/glass/glass_input_field.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../domain/models/category_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../gamification/providers/gamification_provider.dart';
import '../../../wallets/providers/wallet_provider.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../../domain/models/transaction_model.dart';
import '../widgets/transaction_type_bottom_sheet.dart';
import '../widgets/transaction_draft_bottom_sheet.dart';
import '../widgets/transaction_detail_dialog.dart';
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
            color: isDark ? const Color(0xFF161515).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
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
                            Text('home.scan_from_camera'.tr(), style: const TextStyle(fontSize: 12)),
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
                            Text('home.scan_from_gallery'.tr(), style: const TextStyle(fontSize: 12)),
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
          SnackBar(content: Text('Gagal mengambil gambar: $e')),
        );
      }
      return;
    }

    if (image == null) return;

    setState(() => _isProcessingReceipt = true);
    HapticFeedback.mediumImpact();

    try {
      final draft = await ref.read(receiptScannerServiceProvider).scanReceipt(image.path);
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
          SnackBar(content: Text('Gagal memproses struk: $e')),
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
      final draft = await ref.read(transactionNotifierProvider.notifier).parseSmartText(text);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingAI = false);
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

    return walletsAsync.when(
      data: (wallets) {
        if (wallets.isEmpty) return const SizedBox.shrink();

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
                      'Dompet Kamu',
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
                child: _WalletStackedLayout(wallets: wallets, isDark: isDark),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 120.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildQuickActionRow(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildQuickActionItem(
              icon: Icons.add_rounded,
              label: 'home.new_transaction'.tr(),
              onTap: _showTransactionBottomSheet,
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildQuickActionItem(
              icon: Icons.account_balance_wallet_rounded,
              label: 'profile.manage_wallets'.tr(),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/manage-wallets');
              },
              isDark: isDark,
            ),
            const SizedBox(width: 12),
            _buildQuickActionItem(
              icon: Icons.grid_view_rounded,
              label: 'profile.manage_categories'.tr(),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/categories');
              },
              isDark: isDark,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 120.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GlassCard(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.7),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_HomeFeedItem> _buildFeedItems(List<TransactionModel> transactions) {
    final recentTxs = transactions.take(10).toList();
    final Map<DateTime, List<TransactionModel>> grouped = {};
    for (final tx in recentTxs) {
      final dateOnly = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
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
    final gamification = ref.watch(gamificationProvider);
    final txAsync = ref.watch(transactionNotifierProvider);
    final walletsAsync = ref.watch(walletProvider);
    final categoriesAsync = ref.watch(categoryNotifierProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    // Listen for widget clicks while the app is actively running in memory
    ref.listen<bool>(widgetLaunchProvider, (previous, next) {
      if (next) {
        ref.read(widgetLaunchProvider.notifier).state = false;
        Future.microtask(() {
          _showTransactionBottomSheet();
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Premium Background with Glassmorphism
          const PremiumBackground(),

          // 2. Main Scroll Content
          SafeArea(
            child: RefreshIndicator(
              onRefresh: () => ref.read(transactionNotifierProvider.notifier).loadTransactions(),
              color: theme.colorScheme.primary,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // --- HEADER ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _getTimeOfDay(),
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                         SizedBox(
                                           width: 16,
                                           height: 16,
                                           child: Lottie.asset(
                                             'assets/animations/streak.json',
                                             fit: BoxFit.contain,
                                             errorBuilder: (context, error, stackTrace) => const Icon(
                                               Icons.local_fire_department_rounded,
                                               color: Colors.orange,
                                               size: 16,
                                             ),
                                           ),
                                         ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'home.streak_days'.tr(args: ['${gamification.currentStreak}']),
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    ref.watch(displayNameProvider).isNotEmpty
                                        ? ref.watch(displayNameProvider)
                                        : (user?.email.split('@').first ?? 'User'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent.withValues(alpha: 0.1),
                                      border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.2)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'home.health_label'.tr(args: ['${gamification.healthScore}']),
                                      style: const TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.add_rounded, color: isDark ? Colors.white : Colors.black87),
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  padding: const EdgeInsets.all(12),
                                  onPressed: _showTransactionBottomSheet,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : Colors.black87),
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  padding: const EdgeInsets.all(12),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad),
                  ),

                  // --- ASSETS CARD ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: GlassCard(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/manage-wallets');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              colors: isDark 
                                  ? const [Color(0xFF0F172A), Color(0xFF0F2D30)]
                                  : [Colors.teal.withValues(alpha: 0.08), Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: isDark ? const Color(0x3306B6D4) : const Color(0x330D9488)),
                          ),
                          child: txAsync.when(
                            data: (txs) {
                              final wallets = walletsAsync.value ?? [];
                              final balance = wallets.fold<double>(0, (sum, w) => sum + w.balance);
                              final monthlyInc = _calculateMonthlyCashflow(txs, 'income');
                              final monthlyExp = _calculateMonthlyCashflow(txs, 'expense');
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'home.balance'.tr().toUpperCase(),
                                            style: TextStyle(
                                              color: isDark ? const Color(0xFF06B6D4) : const Color(0xFF0D9488),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            formatCurrency.format(balance),
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black87,
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        width: 48,
                                        height: 48,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                        ),
                                        child: Lottie.asset(
                                          'assets/animations/wallet.json',
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) => Icon(
                                            Icons.account_balance_wallet_rounded,
                                            color: isDark ? const Color(0xFF06B6D4) : const Color(0xFF0D9488),
                                            size: 24,
                                          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                           .scaleXY(begin: 0.95, end: 1.05, duration: 1500.ms, curve: Curves.easeInOut),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'home.monthly_income'.tr(),
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                              const SizedBox(width: 6),
                                              Text(
                                                formatCurrency.format(monthlyInc),
                                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.1)),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'home.monthly_expense'.tr(),
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                formatCurrency.format(monthlyExp),
                                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                            error: (error, stack) => const Text('Error loading assets', style: TextStyle(color: Colors.red)),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 100.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack),
                  ),

                  // --- QUICK ACTIONS ROW ---
                  SliverToBoxAdapter(
                    child: _buildQuickActionRow(theme, isDark),
                  ),

                  // --- WALLET TILTED STACK ---
                  SliverToBoxAdapter(
                    child: _buildWalletTiltedStack(ref, theme, isDark),
                  ),

                  // --- SMART INPUT CARD ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: GlassCard(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: isDark 
                                  ? const [Color(0x1F0D9488), Color(0x0F0F172A)]
                                  : [Colors.teal.withValues(alpha: 0.04), Colors.white.withValues(alpha: 0.95)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: isDark ? const Color(0x2206B6D4) : const Color(0x220D9488)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome,
                                    color: isDark ? const Color(0xFF06B6D4) : const Color(0xFF0D9488),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'home.smart_input_title'.tr(),
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                                      ),
                                      child: GlassInputField(
                                        controller: _homeSmartInputController,
                                        hintText: 'home.smart_input_placeholder'.tr(),
                                        prefixIcon: Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3),
                                          size: 18,
                                        ),
                                        suffixIcon: Row(
                                           mainAxisSize: MainAxisSize.min,
                                           children: [
                                             IconButton(
                                               icon: Icon(
                                                 Icons.camera_alt_outlined,
                                                 color: isDark ? const Color(0xFF06B6D4) : const Color(0xFF0D9488),
                                                 size: 18,
                                               ),
                                               onPressed: _isProcessingAI || _isProcessingReceipt
                                                   ? null
                                                   : _showScanSourceDialog,
                                             ),
                                             IconButton(
                                               key: const Key('submit_smart_input_button'),
                                               icon: _isProcessingAI
                                                   ? SizedBox(
                                                       width: 18,
                                                       height: 18,
                                                       child: CircularProgressIndicator(
                                                         strokeWidth: 2,
                                                         color: theme.colorScheme.primary,
                                                       ),
                                                     )
                                                   : Icon(
                                                       Icons.send_rounded,
                                                       color: isDark ? const Color(0xFF06B6D4) : const Color(0xFF0D9488),
                                                       size: 18,
                                                     ),
                                               onPressed: _isProcessingAI || _isProcessingReceipt
                                                   ? null
                                                   : () => _submitHomeSmartInput(_homeSmartInputController.text),
                                             ),
                                           ],
                                         ),
                                        onEditingComplete: _isProcessingAI
                                            ? null
                                            : () => _submitHomeSmartInput(_homeSmartInputController.text),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_isProcessingAI) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: const LinearProgressIndicator(
                                    minHeight: 2,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF818cf8)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 500.ms, delay: 150.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
                  ),

                  // --- SAVINGS GOALS ENTRY ---
                  SliverToBoxAdapter(
                    child: Padding(
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
                                  ? const [Color(0x1F10B981), Color(0x0F0F172A)]
                                  : [Colors.green.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.95)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.green.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'goals.title'.tr(),
                                      style: TextStyle(
                                        color: isDark ? Colors.white : Colors.black87,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'goals.home_subtitle'.tr(),
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
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
                                child: Icon(Icons.history, color: isDark ? Colors.white70 : Colors.black54, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'home.recent_transactions'.tr(),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          GlassButton(
                            variant: GlassButtonVariant.text,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              context.push('/history');
                            },
                            child: Text('home.see_all'.tr(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
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
                              child: Text('home.no_transactions'.tr(), style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                            ),
                          ).animate().fadeIn(),
                        );
                      }

                      final feedItems = _buildFeedItems(transactions);

                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = feedItems[index];

                            if (item is _DateHeaderItem) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDateHeader(item.date),
                                      style: TextStyle(
                                        color: isDark ? Colors.white70 : Colors.black54,
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
                                            : (isDark ? Colors.white70 : Colors.black87),
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
                              (c) => c.name.toLowerCase() == tx.category.toLowerCase(),
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
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              child: GlassCard(
                                onTap: () {},
                                onLongPress: () {
                                  TransactionDetailDialog.show(
                                    context,
                                    transaction: tx,
                                    category: matchedCategory,
                                    wallets: walletsAsync.valueOrNull ?? [],
                                  );
                                },
                                enableBlur: false,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.1)),
                                    boxShadow: isDark ? null : [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isExpense ? Colors.orange.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(
                                          isExpense ? Icons.shopping_bag_outlined : Icons.account_balance_wallet_outlined,
                                          color: isExpense ? Colors.orangeAccent : Colors.greenAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.notes.isNotEmpty ? tx.notes : tx.category,
                                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              tx.category.toUpperCase(),
                                              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isExpense ? '-' : '+'}${formatCurrency.format(tx.amount)}',
                                            style: TextStyle(
                                              color: isExpense ? (isDark ? Colors.white : Colors.black87) : Colors.greenAccent,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            DateFormat('HH:mm').format(tx.createdAt),
                                            style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ).liquidStagger(txItem.index);
                          },
                          childCount: feedItems.length,
                        ),
                      );
                    },
                    loading: () => SliverToBoxAdapter(
                      child: Column(
                        children: List.generate(3, (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ).animate(onPlay: (controller) => controller.repeat())
                         .shimmer(duration: 1200.ms, color: Colors.white10)),
                      ),
                    ),
                    error: (error, _) => SliverToBoxAdapter(child: Center(child: Text('Error: $error', style: const TextStyle(color: Colors.red)))),
                  ),

                  // --- UPCOMING RECURRING TRANSACTIONS ---
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: UpcomingRecurringDashboardWidget(),
                    ),
                  ),

                  // Bottom padding for FAB
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
          if (_isProcessingReceipt)
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.4),
                    child: Center(
                      child: GlassCard(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
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

  const _WalletStackedLayout({required this.wallets, required this.isDark});

  @override
  State<_WalletStackedLayout> createState() => _WalletStackedLayoutState();
}

class _WalletStackedLayoutState extends State<_WalletStackedLayout> with TickerProviderStateMixin {
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
        return Icons.credit_card_rounded;
    }
  }

  Widget _buildEmvChip() {
    return Container(
      width: 28,
      height: 20,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: const LinearGradient(
          colors: [Color(0xFFFCD34D), Color(0xFFF59E0B), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFFBBF24),
          width: 0.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 7,
            top: 0,
            bottom: 0,
            child: Container(width: 0.5, color: Colors.black12),
          ),
          Positioned(
            left: 14,
            top: 0,
            bottom: 0,
            child: Container(width: 0.5, color: Colors.black12),
          ),
          Positioned(
            left: 21,
            top: 0,
            bottom: 0,
            child: Container(width: 0.5, color: Colors.black12),
          ),
          Positioned(
            top: 6,
            left: 0,
            right: 0,
            child: Container(height: 0.5, color: Colors.black12),
          ),
          Positioned(
            top: 13,
            left: 0,
            right: 0,
            child: Container(height: 0.5, color: Colors.black12),
          ),
        ],
      ),
    );
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
    final formatCurrency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final L = widget.wallets.length;
    
    const double cardHeight = 125.0;
    final double totalBalance = widget.wallets.fold(0.0, (sum, w) => sum + w.balance);

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
                  _expansionController.animateTo(0.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack);
                } else {
                  _expansionController.animateTo(1.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack);
                }
              },
              onVerticalDragUpdate: (details) {
                if (_animatingIndex != null) return;
                final double delta = -details.delta.dy / 150.0;
                _expansionController.value = (_expansionController.value + delta).clamp(0.0, 1.0);
              },
              onVerticalDragEnd: (details) {
                if (_animatingIndex != null) return;
                final double velocity = details.primaryVelocity ?? 0.0;
                if (velocity < -300) {
                  _expansionController.animateTo(1.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
                } else if (velocity > 300) {
                  _expansionController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
                } else {
                  if (_expansionController.value >= 0.5) {
                    _expansionController.animateTo(1.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack);
                  } else {
                    _expansionController.animateTo(0.0, duration: const Duration(milliseconds: 350), curve: Curves.easeOutBack);
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
                      offsetY = normalOffsetY + (_openController.value * -130.0);
                      scale = normalScale + (_openController.value * (1.05 - normalScale));
                      opacity = normalOpacity + (_openController.value * (1.0 - normalOpacity));
                    } else if (isAnyTarget) {
                      opacity = normalOpacity * (1.0 - _openController.value * 0.6);
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
                                        color: gradient.first.withValues(alpha: isTarget ? 0.4 : 0.15),
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
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: CardNoisePainter(
                                              color: Colors.white.withValues(alpha: 0.05),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: -10,
                                          bottom: -20,
                                          child: Icon(
                                            _getIconForType(wallet.type),
                                            size: 100,
                                            color: Colors.white.withValues(alpha: 0.06),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      wallet.name,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    formatCurrency.format(wallet.balance),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  _buildEmvChip(),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.2),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      wallet.type.toUpperCase(),
                                                      style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
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
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
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
                                          ? const [Color(0xFF1e1b4b), Color(0xFF0f172a)]
                                          : const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: CardNoisePainter(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -10,
                                bottom: -20,
                                child: Icon(
                                  Icons.all_inclusive_rounded,
                                  size: 100,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'TOTAL SALDO'.toUpperCase(),
                                          style: const TextStyle(
                                            color: Color(0xFFC7D2FE),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        Icon(
                                          Icons.all_inclusive_rounded,
                                          color: widget.isDark ? Colors.white30 : Colors.white70,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      formatCurrency.format(totalBalance),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                      ),
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

class CardNoisePainter extends CustomPainter {
  final Color color;
  const CardNoisePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;
    final random = math.Random(42); 
    for (int i = 0; i < 350; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawPoints(ui.PointMode.points, [ui.Offset(x, y)], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CardNoisePainter oldDelegate) => false;
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
