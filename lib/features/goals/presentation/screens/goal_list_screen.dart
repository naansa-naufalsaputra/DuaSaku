import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/widgets/glass/glass_button.dart';
import '../../domain/models/goal_model.dart';
import '../../domain/models/goal_status.dart';
import '../../providers/goal_provider.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/animations/liquid_animations.dart';
import '../widgets/goal_card.dart';

class GoalListScreen extends ConsumerStatefulWidget {
  const GoalListScreen({super.key});

  @override
  ConsumerState<GoalListScreen> createState() => _GoalListScreenState();
}

class _GoalListScreenState extends ConsumerState<GoalListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    final goalsAsync = ref.watch(goalNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // Header
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
                        'goals.title'.tr(),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: isDark
                        ? Colors.white70
                        : Colors.black54,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      Tab(text: 'goals.tab_active'.tr()),
                      Tab(text: 'goals.tab_completed'.tr()),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tab Content
                Expanded(
                  child: goalsAsync.when(
                    data: (goals) {
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _GoalTabContent(
                            goals: goals
                                .where((g) => g.status == GoalStatus.active)
                                .toList(),
                            isDark: isDark,
                            theme: theme,
                            isActiveTab: true,
                          ),
                          _GoalTabContent(
                            goals: goals
                                .where((g) => g.status == GoalStatus.completed)
                                .toList(),
                            isDark: isDark,
                            theme: theme,
                            isActiveTab: false,
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        _ShimmerLoading(isDark: isDark, theme: theme),
                    error: (error, stack) => _ErrorState(
                      isDark: isDark,
                      theme: theme,
                      onRetry: () => ref.invalidate(goalNotifierProvider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add_goal_fab'),
        onPressed: () {
          HapticFeedback.mediumImpact();
          context.push('/goals/create');
        },
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// ─── Tab Content ──────────────────────────────────────────────────────────────

class _GoalTabContent extends StatelessWidget {
  final List<GoalModel> goals;
  final bool isDark;
  final ThemeData theme;
  final bool isActiveTab;

  const _GoalTabContent({
    required this.goals,
    required this.isDark,
    required this.theme,
    required this.isActiveTab,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return _EmptyState(
        isDark: isDark,
        theme: theme,
        isActiveTab: isActiveTab,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GoalCard(
            goal: goal,
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/goals/${goal.id}');
            },
          ),
        ).liquidStagger(index);
      },
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final bool isActiveTab;

  const _EmptyState({
    required this.isDark,
    required this.theme,
    required this.isActiveTab,
  });

  @override
  Widget build(BuildContext context) {
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
                isActiveTab
                    ? Icons.savings_outlined
                    : Icons.emoji_events_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'goals.empty_state'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isActiveTab
                  ? 'goals.empty_state_desc'.tr()
                  : 'goals.empty_completed_desc'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (isActiveTab) ...[
              const SizedBox(height: 32),
              GlassButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/goals/create');
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'goals.btn_create_first'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.isDark,
    required this.theme,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'goals.error_loading'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GlassButton(
              onPressed: onRetry,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'goals.btn_retry'.tr(),
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
    );
  }
}

// ─── Shimmer Loading ──────────────────────────────────────────────────────────

class _ShimmerLoading extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _ShimmerLoading({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Shimmer.fromColors(
            baseColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey[300]!,
            highlightColor: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey[100]!,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon placeholder
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title placeholder
                      Container(
                        width: 140,
                        height: 14,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.grey[200],
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Progress bar placeholder
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Percentage placeholder
                  Container(
                    width: 40,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(6),
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
