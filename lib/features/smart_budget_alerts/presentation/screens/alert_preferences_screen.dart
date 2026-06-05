import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../transactions/providers/category_provider.dart';
import '../../providers/alert_center_provider.dart';
import '../../providers/alert_preferences_provider.dart';

/// Screen for configuring budget alert preferences.
///
/// Provides:
/// - Master toggle to enable/disable all alerts (Req 3.7)
/// - Threshold chip selector (multiples of 5, 10-100) (Req 3.2)
/// - Prediction alerts toggle (Req 3.3)
/// - Per-category alert toggles (Req 3.1)
/// - Quiet hours time pickers (Req 3.4)
///
/// Changes save immediately to DB (Req 3.6).
class AlertPreferencesScreen extends ConsumerWidget {
  const AlertPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(alertPreferencesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(
          'alert_preferences.title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: prefsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Text(
                  'alert_preferences.error_loading'.tr(),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
              data: (prefs) => _PreferencesBody(prefs: prefs),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesBody extends ConsumerWidget {
  const _PreferencesBody({required this.prefs});

  final dynamic prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = prefs.isEnabled as bool;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ─── Master Toggle Section ──────────────────────────────────────
        _SectionCard(
          child: SwitchListTile(
            title: Text(
              'alert_preferences.master_toggle'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              'alert_preferences.master_toggle_subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            value: isEnabled,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              ref
                  .read(alertPreferencesProvider.notifier)
                  .toggleMasterSwitch(value);
            },
            secondary: Icon(
              isEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ─── Threshold Configuration Section ────────────────────────────
        _SectionCard(
          enabled: isEnabled,
          child: _ThresholdSection(enabled: isEnabled),
        ),

        const SizedBox(height: 12),

        // ─── Prediction Alerts Section ──────────────────────────────────
        _SectionCard(
          enabled: isEnabled,
          child: SwitchListTile(
            title: Text(
              'alert_preferences.prediction_toggle'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isEnabled
                    ? null
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            subtitle: Text(
              'alert_preferences.prediction_toggle_subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(
                  alpha: isEnabled ? 0.6 : 0.3,
                ),
              ),
            ),
            value: prefs.predictionsEnabled as bool,
            onChanged: isEnabled
                ? (value) {
                    HapticFeedback.lightImpact();
                    ref
                        .read(alertPreferencesProvider.notifier)
                        .togglePredictions(value);
                  }
                : null,
            secondary: Icon(
              Icons.trending_up_rounded,
              color: isEnabled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ─── Per-Category Alerts Section ────────────────────────────────
        _SectionCard(
          enabled: isEnabled,
          child: _CategoryAlertsSection(enabled: isEnabled),
        ),

        const SizedBox(height: 12),

        // ─── Quiet Hours Section ────────────────────────────────────────
        _SectionCard(
          enabled: isEnabled,
          child: _QuietHoursSection(enabled: isEnabled),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Section Card Wrapper ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedOpacity(
      opacity: enabled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: child,
      ),
    );
  }
}

// ─── Threshold Configuration Section ──────────────────────────────────────────

class _ThresholdSection extends ConsumerWidget {
  const _ThresholdSection({required this.enabled});

  final bool enabled;

  /// All valid threshold values: multiples of 5 from 10 to 100.
  static const List<int> _allThresholds = [
    10, 15, 20, 25, 30, 35, 40, 45, 50,
    55, 60, 65, 70, 75, 80, 85, 90, 95, 100,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prefs = ref.watch(alertPreferencesProvider).valueOrNull;
    final selectedThresholds = prefs?.thresholds ?? const [50, 75, 90, 100];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed_rounded,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'alert_preferences.threshold_title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: enabled
                        ? null
                        : colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'alert_preferences.threshold_subtitle'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(
                alpha: enabled ? 0.6 : 0.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allThresholds.map((value) {
              final isSelected = selectedThresholds.contains(value);
              return FilterChip(
                label: Text('$value%'),
                selected: isSelected,
                onSelected: enabled
                    ? (selected) {
                        HapticFeedback.selectionClick();
                        _onThresholdToggled(ref, selectedThresholds, value,
                            selected, context);
                      }
                    : null,
                selectedColor:
                    colorScheme.primary.withValues(alpha: 0.15),
                checkmarkColor: colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.5)
                        : colorScheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _onThresholdToggled(
    WidgetRef ref,
    List<int> currentThresholds,
    int value,
    bool selected,
    BuildContext context,
  ) {
    final updated = List<int>.from(currentThresholds);
    if (selected) {
      updated.add(value);
    } else {
      updated.remove(value);
    }
    updated.sort();

    ref.read(alertPreferencesProvider.notifier).updateThresholds(updated).then(
      (result) {
        if (result case Failure(:final error)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      },
    );
  }
}

// ─── Per-Category Alerts Section ──────────────────────────────────────────────

class _CategoryAlertsSection extends ConsumerWidget {
  const _CategoryAlertsSection({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final categoriesAsync = ref.watch(categoryNotifierProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category_rounded,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'alert_preferences.category_title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: enabled
                        ? null
                        : colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'alert_preferences.category_subtitle'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(
                alpha: enabled ? 0.6 : 0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          categoriesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Text(
              'alert_preferences.category_error'.tr(),
              style: TextStyle(color: colorScheme.error),
            ),
            data: (categories) {
              // Only show expense categories (alerts are for spending)
              final expenseCategories =
                  categories.where((c) => c.type == 'expense').toList();

              if (expenseCategories.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'alert_preferences.no_categories'.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                );
              }

              return Column(
                children: expenseCategories.map((category) {
                  return _CategoryToggleItem(
                    categoryId: category.id!,
                    categoryName: category.name,
                    enabled: enabled,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryToggleItem extends ConsumerStatefulWidget {
  const _CategoryToggleItem({
    required this.categoryId,
    required this.categoryName,
    required this.enabled,
  });

  final String categoryId;
  final String categoryName;
  final bool enabled;

  @override
  ConsumerState<_CategoryToggleItem> createState() =>
      _CategoryToggleItemState();
}

class _CategoryToggleItemState extends ConsumerState<_CategoryToggleItem> {
  // Default to enabled until we load category-specific prefs
  bool _isEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategoryPreference();
  }

  Future<void> _loadCategoryPreference() async {
    final repo = ref.read(alertPreferencesRepositoryProvider);
    final prefs = ref.read(alertPreferencesProvider).valueOrNull;
    if (prefs == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await repo.getCategoryPreferences(
      prefs.userId,
      widget.categoryId,
    );

    if (!mounted) return;

    switch (result) {
      case Success(:final value):
        setState(() {
          _isEnabled = value?.isEnabled ?? true;
          _isLoading = false;
        });
      case Failure():
        setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return ListTile(
        title: Text(widget.categoryName),
        trailing: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return SwitchListTile(
      title: Text(
        widget.categoryName,
        style: TextStyle(
          color: widget.enabled
              ? null
              : colorScheme.onSurface.withValues(alpha: 0.4),
        ),
      ),
      value: _isEnabled,
      onChanged: widget.enabled
          ? (value) {
              HapticFeedback.lightImpact();
              setState(() => _isEnabled = value);
              ref
                  .read(alertPreferencesProvider.notifier)
                  .toggleCategoryAlerts(widget.categoryId, value);
            }
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      dense: true,
    );
  }
}

// ─── Quiet Hours Section ──────────────────────────────────────────────────────

class _QuietHoursSection extends ConsumerWidget {
  const _QuietHoursSection({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final prefs = ref.watch(alertPreferencesProvider).valueOrNull;
    final hasQuietHours = prefs?.hasQuietHours ?? false;
    final startTime = prefs?.quietHoursStart;
    final endTime = prefs?.quietHoursEnd;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.do_not_disturb_on_rounded,
                color: enabled
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'alert_preferences.quiet_hours_title'.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: enabled
                        ? null
                        : colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
              Switch(
                value: hasQuietHours,
                onChanged: enabled
                    ? (value) {
                        HapticFeedback.lightImpact();
                        if (!value) {
                          // Disable quiet hours
                          ref
                              .read(alertPreferencesProvider.notifier)
                              .setQuietHours(null, null);
                        } else {
                          // Enable with default 22:00 - 07:00
                          ref
                              .read(alertPreferencesProvider.notifier)
                              .setQuietHours('22:00', '07:00');
                        }
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'alert_preferences.quiet_hours_subtitle'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(
                alpha: enabled ? 0.6 : 0.3,
              ),
            ),
          ),
          if (hasQuietHours && enabled) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimePickerTile(
                    label: 'alert_preferences.quiet_start'.tr(),
                    time: startTime ?? '22:00',
                    onTimePicked: (newTime) {
                      ref
                          .read(alertPreferencesProvider.notifier)
                          .setQuietHours(newTime, endTime ?? '07:00');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerTile(
                    label: 'alert_preferences.quiet_end'.tr(),
                    time: endTime ?? '07:00',
                    onTimePicked: (newTime) {
                      ref
                          .read(alertPreferencesProvider.notifier)
                          .setQuietHours(startTime ?? '22:00', newTime);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onTimePicked,
  });

  final String label;
  final String time;
  final ValueChanged<String> onTimePicked;

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hour.toString().padLeft(2, '0');
    final minute = tod.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tod = _parseTime(time);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        HapticFeedback.lightImpact();
        final picked = await showTimePicker(
          context: context,
          initialTime: tod,
        );
        if (picked != null) {
          onTimePicked(_formatTimeOfDay(picked));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              tod.format(context),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
