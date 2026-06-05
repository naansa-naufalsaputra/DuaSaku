import 'package:flutter/material.dart';

import '../../theme/liquid_glass_theme.dart';
import 'glass_surface.dart';

/// A modal bottom sheet rendered with a [GlassSurface] treatment.
///
/// Uses 1.5x the standard blur sigma for a stronger frosted effect.
/// Entry animation: slide-up + scale(0.95→1.0) + fade-in over 300ms.
/// Displays a drag handle pill (40x4px) at the top when [showDragHandle] is true.
class GlassBottomSheet extends StatelessWidget {
  /// The content rendered inside the glass bottom sheet.
  final Widget child;

  /// Whether to display the drag handle pill at the top. Defaults to true.
  final bool showDragHandle;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    final blurSigma = (glassTheme?.blurSigma ?? 12.0) * 1.5;

    return GlassSurface(
      blurSigma: blurSigma,
      borderRadius: 24.0,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) ...[
            const _DragHandle(),
            const SizedBox(height: 12),
          ],
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// The drag handle pill rendered at the top of the bottom sheet.
/// 40x4px with rounded corners and a subtle white/grey color.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: colorScheme.onSurface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Shows a modal bottom sheet with a glass surface treatment.
///
/// Uses [showModalBottomSheet] internally with a custom builder that wraps
/// the content in a [GlassBottomSheet]. Scrim color is black at 40% opacity.
/// Entry animation: slide-up + scale(0.95→1.0) + fade-in over 300ms.
Future<T?> showGlassBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  bool showDragHandle = true,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  final glassTheme = LiquidGlassTheme.of(context);
  final duration =
      glassTheme?.animationDuration ?? const Duration(milliseconds: 300);
  final curve = glassTheme?.animationCurve ?? Curves.easeOutCubic;

  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: duration,
    ),
    builder: (sheetContext) {
      return _GlassBottomSheetEntry(
        duration: duration,
        curve: curve,
        child: GlassBottomSheet(
          showDragHandle: showDragHandle,
          child: child,
        ),
      );
    },
  );
}

/// Internal widget that applies the entry animation:
/// slide-up + scale(0.95→1.0) + fade-in.
class _GlassBottomSheetEntry extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const _GlassBottomSheetEntry({
    required this.child,
    required this.duration,
    required this.curve,
  });

  @override
  State<_GlassBottomSheetEntry> createState() =>
      _GlassBottomSheetEntryState();
}

class _GlassBottomSheetEntryState extends State<_GlassBottomSheetEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      curvedAnimation,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      curvedAnimation,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(curvedAnimation);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionalTranslation(
          translation: _slideAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
