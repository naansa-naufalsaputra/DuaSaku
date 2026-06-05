import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lottie/lottie.dart';

/// Empty state widget displayed when the Alert Center has no alerts.
///
/// Shows a Lottie animation with an informative message indicating
/// that no budget alerts have been generated yet.
class AlertEmptyStateWidget extends StatelessWidget {
  const AlertEmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Lottie.asset(
                'assets/animations/empty_alerts.json',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'alert.empty_title'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'alert.empty_description'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
