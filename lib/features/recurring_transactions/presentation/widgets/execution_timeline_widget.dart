import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/models/execution_log_model.dart';

/// Visual timeline widget showing past executions (with status) and upcoming
/// scheduled dates for a recurring transaction.
///
/// Displays a vertical timeline with colored dots and connecting lines:
/// - Green dot: successful past execution
/// - Red dot: failed past execution
/// - Grey dot: upcoming scheduled execution
///
/// Accepts:
/// - [pastExecutions]: List of past execution logs (max 5 displayed).
/// - [upcomingDates]: List of upcoming scheduled dates (max 5 displayed).
class ExecutionTimelineWidget extends StatelessWidget {
  const ExecutionTimelineWidget({
    super.key,
    required this.pastExecutions,
    required this.upcomingDates,
  });

  /// Past execution log entries. Only the most recent 5 are displayed.
  final List<ExecutionLogModel> pastExecutions;

  /// Upcoming scheduled execution dates. Only the next 5 are displayed.
  final List<DateTime> upcomingDates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Limit to max 5 each
    final displayedPast = pastExecutions.length > 5
        ? pastExecutions.sublist(pastExecutions.length - 5)
        : pastExecutions;
    final displayedUpcoming =
        upcomingDates.length > 5 ? upcomingDates.sublist(0, 5) : upcomingDates;

    final hasEntries = displayedPast.isNotEmpty || displayedUpcoming.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.6)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Text(
            'recurring.execution_timeline'.tr(),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasEntries)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'recurring.no_executions_yet'.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            )
          else
            _buildTimeline(
              context,
              displayedPast,
              displayedUpcoming,
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    List<ExecutionLogModel> past,
    List<DateTime> upcoming,
    bool isDark,
  ) {
    final items = <_TimelineEntry>[];

    // Add past executions (oldest first)
    for (final log in past) {
      items.add(_TimelineEntry(
        date: log.executedAt,
        type: log.isSuccess
            ? _TimelineEntryType.success
            : _TimelineEntryType.failed,
        errorMessage: log.errorMessage,
      ));
    }

    // Add upcoming dates
    for (final date in upcoming) {
      items.add(_TimelineEntry(
        date: date,
        type: _TimelineEntryType.upcoming,
      ));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(items.length, (index) {
            final entry = items[index];
            final isLast = index == items.length - 1;

            return _TimelineItemWidget(
              entry: entry,
              isLast: isLast,
              isDark: isDark,
            )
                .animate()
                .fadeIn(
                  duration: 300.ms,
                  delay: Duration(milliseconds: index * 50),
                  curve: Curves.easeOutCubic,
                )
                .slideX(
                  begin: -0.05,
                  end: 0,
                  duration: 300.ms,
                  delay: Duration(milliseconds: index * 50),
                  curve: Curves.easeOutCubic,
                );
          }),
        ),
      ),
    );
  }
}

// ─── Timeline Entry Model ─────────────────────────────────────────────────────

enum _TimelineEntryType { success, failed, upcoming }

class _TimelineEntry {
  final DateTime date;
  final _TimelineEntryType type;
  final String? errorMessage;

  const _TimelineEntry({
    required this.date,
    required this.type,
    this.errorMessage,
  });
}

// ─── Timeline Item Widget ─────────────────────────────────────────────────────

class _TimelineItemWidget extends StatelessWidget {
  const _TimelineItemWidget({
    required this.entry,
    required this.isLast,
    required this.isDark,
  });

  final _TimelineEntry entry;
  final bool isLast;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('dd MMM yyyy');

    final dotColor = switch (entry.type) {
      _TimelineEntryType.success => Colors.green,
      _TimelineEntryType.failed => colorScheme.error,
      _TimelineEntryType.upcoming => colorScheme.onSurface.withValues(alpha: 0.3),
    };

    final lineColor = colorScheme.onSurface.withValues(alpha: 0.1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column (dot + line)
          SizedBox(
            width: 32,
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: entry.type != _TimelineEntryType.upcoming
                        ? [
                            BoxShadow(
                              color: dotColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                // Connecting line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content column
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date
                  Text(
                    dateFormat.format(entry.date),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Status label
                  _buildStatusLabel(context),
                  // Error message (if failed)
                  if (entry.type == _TimelineEntryType.failed &&
                      entry.errorMessage != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      entry.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error.withValues(alpha: 0.8),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLabel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final (label, color) = switch (entry.type) {
      _TimelineEntryType.success => (
          'recurring.status_success'.tr(),
          Colors.green,
        ),
      _TimelineEntryType.failed => (
          'recurring.status_failed'.tr(),
          colorScheme.error,
        ),
      _TimelineEntryType.upcoming => (
          'recurring.status_scheduled'.tr(),
          colorScheme.onSurface.withValues(alpha: 0.5),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
