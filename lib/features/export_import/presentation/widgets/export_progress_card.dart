import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/glass/glass_card.dart';
import '../../domain/models/export_progress.dart';

/// A glassmorphism card that displays export progress.
///
/// Shows a [LinearProgressIndicator] with the current percentage,
/// the name of the table being processed, and estimated time remaining.
class ExportProgressCard extends StatelessWidget {
  /// The current export progress state.
  final ExportProgress progress;

  const ExportProgressCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      enableBlur: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'export_import.progress.exporting'.tr(),
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.percentage,
              minHeight: 8,
              backgroundColor: colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 8),

          // Percentage and current table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress.percentage * 100).toInt()}%',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Flexible(
                child: Text(
                  'export_import.progress.processing_table'.tr(
                    args: [progress.currentTable],
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Estimated time remaining
          if (progress.estimatedRemaining != null) ...[
            const SizedBox(height: 4),
            Text(
              'export_import.progress.estimated_remaining'.tr(
                args: [_formatDuration(progress.estimatedRemaining!)],
              ),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
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
