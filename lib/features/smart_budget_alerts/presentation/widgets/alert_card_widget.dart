import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/models/alert_type.dart';
import '../../domain/models/budget_alert_model.dart';

/// A card widget that displays a single budget alert record.
///
/// Shows alert type icon, category name, message, relative timestamp,
/// and a read/unread indicator dot.
class AlertCardWidget extends StatelessWidget {
  const AlertCardWidget({
    super.key,
    required this.alert,
    this.onDismissed,
    this.onTap,
  });

  final BudgetAlertModel alert;
  final VoidCallback? onDismissed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.error,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alert type icon
              _AlertTypeIcon(alertType: alert.alertType, theme: theme),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category name + unread indicator
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.categoryName ?? 'alert.default_category'.tr(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: alert.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!alert.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Alert message
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: alert.isRead
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Timestamp
                    Text(
                      _formatRelativeTime(alert.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formats a DateTime to a relative time string in Indonesian.
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'alert.time_just_now'.tr();
    } else if (difference.inMinutes < 60) {
      return 'alert.time_minutes_ago'.tr(args: ['${difference.inMinutes}']);
    } else if (difference.inHours < 24) {
      return 'alert.time_hours_ago'.tr(args: ['${difference.inHours}']);
    } else if (difference.inDays == 1) {
      return 'alert.time_yesterday'.tr();
    } else if (difference.inDays < 7) {
      return 'alert.time_days_ago'.tr(args: ['${difference.inDays}']);
    } else {
      return 'alert.time_date'.tr(
        args: ['${dateTime.day}/${dateTime.month}/${dateTime.year}'],
      );
    }
  }
}

/// Icon widget that displays the appropriate icon based on alert type.
class _AlertTypeIcon extends StatelessWidget {
  const _AlertTypeIcon({required this.alertType, required this.theme});

  final AlertType alertType;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (alertType) {
      AlertType.threshold => (Icons.warning_amber_rounded, Colors.orange),
      AlertType.prediction => (
        Icons.trending_up_rounded,
        theme.colorScheme.primary,
      ),
      AlertType.overBudget => (
        Icons.error_outline_rounded,
        theme.colorScheme.error,
      ),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
