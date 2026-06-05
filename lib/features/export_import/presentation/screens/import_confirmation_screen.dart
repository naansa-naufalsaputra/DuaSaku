import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../providers/import_provider.dart';
import '../widgets/import_summary_card.dart';

/// Import confirmation screen that shows a preview of backup data
/// and allows the user to confirm or cancel the restore operation.
///
/// - Shows ImportSummaryCard with preview data counts
/// - Shows destructive warning about data replacement
/// - Cancel and Restore buttons (Restore is destructive/red)
/// - Progress indicator during restore with percentage and table name
/// - Success message after restore completes
///
/// Requirements: 4.3, 4.4, 4.8, 6.5, 7.4, 7.5, 7.6
class ImportConfirmationScreen extends ConsumerStatefulWidget {
  const ImportConfirmationScreen({super.key});

  @override
  ConsumerState<ImportConfirmationScreen> createState() =>
      _ImportConfirmationScreenState();
}

class _ImportConfirmationScreenState
    extends ConsumerState<ImportConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    // If no preview exists yet, trigger file pick and preview
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(importNotifierProvider).valueOrNull;
      if (state?.preview == null) {
        ref.read(importNotifierProvider.notifier).pickAndPreviewFile();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final importState = ref.watch(importNotifierProvider);

    return importState.when(
      data: (state) => _buildContent(context, state),
      loading: () => _buildLoadingScaffold(context),
      error: (error, _) => _buildErrorScaffold(context, error),
    );
  }

  Widget _buildLoadingScaffold(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text('export_import.import.title'.tr())),
      body: Stack(
        children: [
          const PremiumBackground(),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'export_import.import.loading'.tr(),
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScaffold(BuildContext context, Object error) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: Text('export_import.import.title'.tr())),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: GlassCard(
                  enableBlur: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'export_import.import.error_title'.tr(),
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      GlassButton(
                        variant: GlassButtonVariant.secondary,
                        onPressed: () => context.pop(),
                        child: Text('export_import.import.back'.tr()),
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

  Widget _buildContent(BuildContext context, ImportState state) {
    final isRestoring = state.isRestoring;

    return PopScope(
      canPop: !isRestoring,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: Text('export_import.import.title'.tr()),
          leading: isRestoring
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    ref.read(importNotifierProvider.notifier).cancelImport();
                    context.pop();
                  },
                ),
        ),
        body: Stack(
          children: [
            const PremiumBackground(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Restore complete state
                    if (state.restoreComplete) ...[
                      _RestoreSuccessContent(state: state),
                    ]
                    // Restoring in progress
                    else if (isRestoring) ...[
                      if (state.preview != null)
                        ImportSummaryCard(preview: state.preview!),
                      const SizedBox(height: 20),
                      _RestoreProgressContent(state: state),
                    ]
                    // Preview state - show summary and confirm buttons
                    else if (state.preview != null) ...[
                      ImportSummaryCard(preview: state.preview!),
                      const SizedBox(height: 20),
                      _DestructiveWarning(),
                      const SizedBox(height: 24),
                      _ActionButtons(state: state),
                    ]
                    // No preview yet - waiting for file pick
                    else ...[
                      _NoPreviewContent(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Destructive Warning ──────────────────────────────────────────────────────

class _DestructiveWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'export_import.import.destructive_warning'.tr(),
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final ImportState state;

  const _ActionButtons({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        // Cancel button
        Expanded(
          child: GlassButton(
            variant: GlassButtonVariant.secondary,
            onPressed: () {
              ref.read(importNotifierProvider.notifier).cancelImport();
              context.pop();
            },
            child: Text('export_import.import.cancel'.tr()),
          ),
        ),
        const SizedBox(width: 12),
        // Restore button (destructive)
        Expanded(
          child: _DestructiveRestoreButton(
            onPressed: () {
              ref.read(importNotifierProvider.notifier).confirmRestore();
            },
          ),
        ),
      ],
    );
  }
}

class _DestructiveRestoreButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _DestructiveRestoreButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Text(
              'export_import.import.restore'.tr(),
              style: TextStyle(
                color: colorScheme.onError,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Restore Progress Content ─────────────────────────────────────────────────

class _RestoreProgressContent extends StatelessWidget {
  final ImportState state;

  const _RestoreProgressContent({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = state.progress;

    return GlassCard(
      enableBlur: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'export_import.import.restoring'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress?.percentage,
              minHeight: 8,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),

          // Percentage and current table
          if (progress != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress.percentage * 100).toInt()}%',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Flexible(
                  child: Text(
                    'export_import.progress.processing_table'.tr(
                      args: [progress.currentTable],
                    ),
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Estimated time remaining
          if (progress?.estimatedRemaining != null) ...[
            const SizedBox(height: 4),
            Text(
              'export_import.progress.estimated_remaining'.tr(
                args: [_formatDuration(progress!.estimatedRemaining!)],
              ),
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    }
    return '${duration.inSeconds}s';
  }
}

// ─── Restore Success Content ──────────────────────────────────────────────────

class _RestoreSuccessContent extends ConsumerWidget {
  final ImportState state;

  const _RestoreSuccessContent({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final preview = state.preview;

    return Column(
      children: [
        GlassCard(
          enableBlur: false,
          child: Column(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 56,
                color: Colors.green.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'export_import.import.success_title'.tr(),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'export_import.import.success_message'.tr(),
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              // Summary of restored data
              if (preview != null) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _RestoreSummaryRow(
                  label: 'export_import.data_type.wallets'.tr(),
                  count: preview.walletCount,
                  colorScheme: colorScheme,
                ),
                _RestoreSummaryRow(
                  label: 'export_import.data_type.categories'.tr(),
                  count: preview.categoryCount,
                  colorScheme: colorScheme,
                ),
                _RestoreSummaryRow(
                  label: 'export_import.data_type.transactions'.tr(),
                  count: preview.transactionCount,
                  colorScheme: colorScheme,
                ),
                _RestoreSummaryRow(
                  label: 'export_import.data_type.budgets'.tr(),
                  count: preview.budgetCount,
                  colorScheme: colorScheme,
                ),
                _RestoreSummaryRow(
                  label: 'export_import.data_type.goals'.tr(),
                  count: preview.goalCount,
                  colorScheme: colorScheme,
                ),
                _RestoreSummaryRow(
                  label: 'export_import.data_type.recurring_transactions'.tr(),
                  count: preview.recurringTransactionCount,
                  colorScheme: colorScheme,
                ),
                _RestoreSummaryRow(
                  label: 'export_import.data_type.budget_alerts'.tr(),
                  count: preview.budgetAlertCount,
                  colorScheme: colorScheme,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Back to home button
        GlassButton(
          onPressed: () => context.go('/home'),
          child: Text('export_import.import.back_to_home'.tr()),
        ),
      ],
    );
  }
}

class _RestoreSummaryRow extends StatelessWidget {
  final String label;
  final int count;
  final ColorScheme colorScheme;

  const _RestoreSummaryRow({
    required this.label,
    required this.count,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── No Preview Content ───────────────────────────────────────────────────────

class _NoPreviewContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      enableBlur: false,
      child: Column(
        children: [
          Icon(
            Icons.file_open_outlined,
            size: 48,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'export_import.import.no_file_selected'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GlassButton(
            variant: GlassButtonVariant.secondary,
            onPressed: () {
              ref.read(importNotifierProvider.notifier).pickAndPreviewFile();
            },
            child: Text('export_import.import.select_file'.tr()),
          ),
        ],
      ),
    );
  }
}
