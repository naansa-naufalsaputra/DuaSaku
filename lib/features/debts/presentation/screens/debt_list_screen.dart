import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../providers/debt_provider.dart';
import '../../domain/models/debt_model.dart';

class DebtListScreen extends ConsumerStatefulWidget {
  const DebtListScreen({super.key});

  @override
  ConsumerState<DebtListScreen> createState() => _DebtListScreenState();
}

class _DebtListScreenState extends ConsumerState<DebtListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'all'; // 'all', 'unpaid', 'paid'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final debtsAsync = ref.watch(debtNotifierProvider);
    final currencyFormatter = ref.watch(currencyFormatterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text('debts.title'.tr()),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: theme.colorScheme.primary,
                  labelColor: isDark ? Colors.white : Colors.black87,
                  unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
                  tabs: [
                    Tab(text: 'debts.tab_debts'.tr()),
                    Tab(text: 'debts.tab_loans'.tr()),
                  ],
                ),
                Expanded(
                  child: debtsAsync.when(
                    data: (allDebts) {
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildDebtTab(allDebts, 'debt', isDark, theme, currencyFormatter),
                          _buildDebtTab(allDebts, 'loan', isDark, theme, currencyFormatter),
                        ],
                      );
                    },
                    loading: () => _buildShimmerLoading(isDark, theme),
                    error: (error, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                            const SizedBox(height: 16),
                            Text(
                              'debts.error_loading'.tr(),
                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16),
                              textAlign: TextAlign.center,
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          final currentTabType = _tabController.index == 0 ? 'debt' : 'loan';
          context.push('/debts/create?type=$currentTabType');
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildDebtTab(
    List<DebtModel> allDebts,
    String type,
    bool isDark,
    ThemeData theme,
    NumberFormat formatter,
  ) {
    // Filter by type
    final typeFiltered = allDebts.where((d) => d.type == type).toList();

    // Filter by status
    final filtered = typeFiltered.where((d) {
      if (_statusFilter == 'unpaid') {
        return d.status == 'unpaid' || d.status == 'partial';
      } else if (_statusFilter == 'paid') {
        return d.status == 'paid';
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Status Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('all', 'filters.all'.tr(), theme),
              const SizedBox(width: 8),
              _buildFilterChip('unpaid', 'debts.status_unpaid'.tr(), theme),
              const SizedBox(width: 8),
              _buildFilterChip('paid', 'debts.status_paid'.tr(), theme),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(type, isDark, theme)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final debt = filtered[index];
                    return _buildDebtCard(debt, isDark, theme, formatter).liquidStagger(index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, ThemeData theme) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : (theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.brightness == Brightness.dark ? Colors.white10 : Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.transparent),
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = value;
          });
        }
      },
    );
  }

  Widget _buildEmptyState(String type, bool isDark, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                type == 'debt' ? Icons.assignment_late_rounded : Icons.assignment_ind_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              type == 'debt' ? 'debts.empty_debts'.tr() : 'debts.empty_loans'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtCard(
    DebtModel debt,
    bool isDark,
    ThemeData theme,
    NumberFormat formatter,
  ) {
    final progress = debt.amount > 0 ? (debt.paidAmount / debt.amount) : 0.0;
    final isOverdue = debt.isOverdue;
    final accentColor = debt.type == 'debt' ? theme.colorScheme.error : theme.colorScheme.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.push('/debts/${debt.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      debt.personName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusChip(debt, theme),
                ],
              ),
              const SizedBox(height: 12),

              // Amounts row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'debts.amount'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      Text(
                        formatter.format(debt.amount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'debts.remaining'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      Text(
                        formatter.format(debt.remainingAmount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: debt.isSettled ? Colors.grey : accentColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    debt.isSettled ? Colors.green : accentColor,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 12),

              // Due Date & Warning Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (debt.dueDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: isOverdue ? theme.colorScheme.error : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat.yMMMd().format(debt.dueDate!),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                            color: isOverdue ? theme.colorScheme.error : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(),
                  if (isOverdue)
                    Text(
                      'debts.overdue'.tr().toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(DebtModel debt, ThemeData theme) {
    Color color;
    String text;

    if (debt.status == 'paid') {
      color = Colors.green;
      text = 'debts.status_paid'.tr();
    } else if (debt.status == 'partial') {
      color = Colors.orange;
      text = 'debts.status_partial'.tr();
    } else {
      color = debt.type == 'debt' ? theme.colorScheme.error : theme.colorScheme.primary;
      text = 'debts.status_unpaid'.tr();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(bool isDark, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300]!,
            highlightColor: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey[100]!,
            child: Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}
