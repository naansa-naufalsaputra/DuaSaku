import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeQuickActions extends StatelessWidget {
  final VoidCallback onTopUpTap;
  final VoidCallback onTransferTap;
  final VoidCallback onScanQrTap;

  const HomeQuickActions({
    super.key,
    required this.onTopUpTap,
    required this.onTransferTap,
    required this.onScanQrTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickPill(
                  label: 'home.action_top_up'.tr(),
                  onTap: onTopUpTap,
                  theme: theme,
                  isDark: isDark,
                  isActive: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickPill(
                  label: 'home.action_transfer'.tr(),
                  onTap: onTransferTap,
                  theme: theme,
                  isDark: isDark,
                  isActive: false,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQuickPill(
                  label: 'home.action_scan_qr'.tr(),
                  onTap: onScanQrTap,
                  theme: theme,
                  isDark: isDark,
                  isActive: false,
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms, delay: 120.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildQuickPill({
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
    required bool isDark,
    required bool isActive,
  }) {
    final activeColor = isDark
        ? const Color(0xFF0A84FF)
        : const Color(0xFF007AFF);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final textColor = isActive
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.black87);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          color: isActive ? activeColor : inactiveColor,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
