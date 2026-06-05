import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../domain/models/goal_deposit_model.dart';

/// List tile widget for displaying a single deposit in the deposit history.
///
/// Shows the deposit amount (formatted as currency), optional note, and
/// the date the deposit was made.
///
/// Requirements: 2.5, 5.4
class DepositHistoryTile extends StatelessWidget {
  const DepositHistoryTile({
    super.key,
    required this.deposit,
    this.goalColor,
  });

  /// The deposit model to display.
  final GoalDepositModel deposit;

  /// Optional color accent for the deposit icon. Falls back to primary.
  final Color? goalColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = goalColor ?? colorScheme.primary;

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: 0.4)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          // Deposit icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.add_rounded,
              color: accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Amount and note
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '+${currencyFormat.format(deposit.amount)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                if (deposit.note != null && deposit.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    deposit.note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Date
          Text(
            dateFormat.format(deposit.createdAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
