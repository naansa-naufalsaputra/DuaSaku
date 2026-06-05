import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/unread_badge_provider.dart';

/// A widget that displays an unread alert count badge on top of its child.
///
/// Watches [unreadBadgeCountProvider] for real-time updates.
/// Hides the badge when count is 0, shows "9+" when count exceeds 9.
///
/// Requirements: 4.4
class AlertBadgeWidget extends ConsumerWidget {
  const AlertBadgeWidget({super.key, required this.child});

  /// The child widget (typically a bell/notification icon) to overlay the badge on.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCount = ref.watch(unreadBadgeCountProvider);
    final count = asyncCount.valueOrNull ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(top: -4, right: -4, child: _BadgeCount(count: count)),
      ],
    );
  }
}

class _BadgeCount extends StatelessWidget {
  const _BadgeCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayText = count > 9 ? '9+' : '$count';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      decoration: BoxDecoration(
        color: colorScheme.error,
        shape: displayText.length > 1 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: displayText.length > 1 ? BorderRadius.circular(8) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        displayText,
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
