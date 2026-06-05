import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../domain/models/alert_type.dart';
import '../../domain/models/budget_alert_model.dart';
import '../../providers/alert_center_provider.dart';
import '../widgets/alert_card_widget.dart';
import '../widgets/alert_empty_state_widget.dart';
import 'budget_detail_screen.dart';

/// Alert Center screen that displays all budget alert history.
///
/// Features:
/// - Reactive alert list ordered by createdAt descending
/// - Staggered fade-in animation using flutter_animate
/// - Swipe-to-delete for individual alerts
/// - "Clear All" button to delete all read alerts
/// - Empty state with Lottie animation
/// - Marks all visible alerts as read on open
/// - Supports highlighting a specific alert via [highlightAlertId]
class AlertCenterScreen extends ConsumerStatefulWidget {
  const AlertCenterScreen({super.key, this.highlightAlertId});

  /// Optional alert ID to scroll to and highlight when the screen opens.
  /// Passed via notification tap deep link payload.
  final String? highlightAlertId;

  @override
  ConsumerState<AlertCenterScreen> createState() => _AlertCenterScreenState();
}

class _AlertCenterScreenState extends ConsumerState<AlertCenterScreen> {
  bool _hasMarkedAsRead = false;
  bool _hasScrolledToHighlight = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Mark all visible alerts as read after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markVisibleAlertsAsRead();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markVisibleAlertsAsRead() async {
    if (_hasMarkedAsRead) return;
    _hasMarkedAsRead = true;

    final user = ref.read(userProvider);
    if (user == null) return;

    final repo = ref.read(alertRepositoryProvider);
    await repo.markAllVisibleAsRead(user.id);
  }

  Future<void> _deleteAlert(String alertId) async {
    final repo = ref.read(alertRepositoryProvider);
    await repo.deleteAlert(alertId);
  }

  Future<void> _clearAllReadAlerts() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('alert.clear_all_title'.tr()),
        content: Text('alert.clear_all_confirm'.tr()),
        actions: [
          GlassButton(
            variant: GlassButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          GlassButton(
            variant: GlassButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'alert.clear_all_action'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(alertRepositoryProvider);
      await repo.deleteAllRead(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alertsAsync = ref.watch(alertCenterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text('alert.center_title'.tr()),
        scrollController: _scrollController,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'alert.clear_all_action'.tr(),
            onPressed: () {
              HapticFeedback.lightImpact();
              _clearAllReadAlerts();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: alertsAsync.when(
              data: (alerts) {
                if (alerts.isEmpty) {
                  return const AlertEmptyStateWidget();
                }

                // Scroll to highlighted alert on first data load
                if (!_hasScrolledToHighlight &&
                    widget.highlightAlertId != null) {
                  _hasScrolledToHighlight = true;
                  final index = alerts.indexWhere(
                    (a) => a.id == widget.highlightAlertId,
                  );
                  if (index > 0) {
                    // Delay to allow list to build before scrolling
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      // Approximate item height (card ~100px + margin 12px)
                      final offset = index * 112.0;
                      _scrollController.animateTo(
                        offset,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    });
                  }
                }

                return _AlertList(
                  alerts: alerts,
                  onDismissed: _deleteAlert,
                  highlightAlertId: widget.highlightAlertId,
                  scrollController: _scrollController,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
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
                        'alert.error_loading'.tr(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 16,
                        ),
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
    );
  }
}

// ─── Alert List ───────────────────────────────────────────────────────────────

class _AlertList extends StatelessWidget {
  const _AlertList({
    required this.alerts,
    required this.onDismissed,
    this.highlightAlertId,
    this.scrollController,
  });

  final List<BudgetAlertModel> alerts;
  final Future<void> Function(String alertId) onDismissed;
  final String? highlightAlertId;
  final ScrollController? scrollController;

  /// Navigates to the budget detail screen based on alert type.
  ///
  /// - threshold/overBudget: navigates to budget detail for the category
  /// - prediction: navigates to budget detail with projection info displayed
  void _navigateToDetail(BuildContext context, BudgetAlertModel alert) {
    final showProjection = alert.alertType == AlertType.prediction;
    final extra = BudgetDetailExtra(
      alert: alert,
      showProjection: showProjection,
    );

    context.push(
      '/budgets/detail/${Uri.encodeComponent(alert.categoryId)}',
      extra: extra,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        final isHighlighted = alert.id == highlightAlertId;
        // Cap stagger delay to avoid long waits for large lists
        final staggerIndex = index < 8 ? index : 8;

        Widget card = AlertCardWidget(
          alert: alert,
          onDismissed: () => onDismissed(alert.id),
          onTap: () {
            _navigateToDetail(context, alert);
          },
        );

        // Wrap highlighted alert with a subtle border pulse
        if (isHighlighted) {
          card = Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.6),
                width: 2,
              ),
            ),
            child: card,
          );
        }

        return card
            .animate()
            .fadeIn(
              duration: 300.ms,
              delay: Duration(milliseconds: staggerIndex * 50),
              curve: Curves.easeOutCubic,
            )
            .slideY(
              begin: 0.1,
              end: 0,
              duration: 300.ms,
              delay: Duration(milliseconds: staggerIndex * 50),
              curve: Curves.easeOutCubic,
            );
      },
    );
  }
}
