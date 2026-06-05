import 'package:flutter/material.dart';

import '../../theme/liquid_glass_theme.dart';
import 'glass_button.dart';
import 'glass_surface.dart';

/// A dialog widget rendered with a [GlassSurface] treatment.
///
/// Entry animation: scale(0.9→1.0) + fade-in over 250ms.
/// Scrim: black at 50% opacity.
/// Action buttons are rendered as [GlassButton] widgets.
class GlassDialog extends StatelessWidget {
  /// Optional title widget displayed at the top of the dialog.
  final Widget? title;

  /// Optional content widget displayed in the body of the dialog.
  final Widget? content;

  /// Action buttons rendered as [GlassButton] widgets at the bottom.
  final List<Widget> actions;

  const GlassDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: 20.0,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            DefaultTextStyle(
              style: Theme.of(context).textTheme.titleLarge ??
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              child: title!,
            ),
            const SizedBox(height: 16),
          ],
          if (content != null) ...[
            DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium ??
                  const TextStyle(fontSize: 14),
              child: content!,
            ),
            const SizedBox(height: 24),
          ],
          if (actions.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Flexible(child: actions[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Shows a dialog with a glass surface treatment.
///
/// Uses [showGeneralDialog] internally with a custom builder.
/// Scrim color is black at 50% opacity.
/// Entry animation: scale(0.9→1.0) + fade-in over 250ms with easeOutCubic.
Future<T?> showGlassDialog<T>(
  BuildContext context, {
  required GlassDialog dialog,
  bool barrierDismissible = true,
  String? barrierLabel,
}) {
  final glassTheme = LiquidGlassTheme.of(context);
  // Dialog uses a slightly faster animation (250ms) per spec.
  const dialogDuration = Duration(milliseconds: 250);
  final curve = glassTheme?.animationCurve ?? Curves.easeOutCubic;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: dialogDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 340,
            minWidth: 280,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: dialog,
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: child,
        ),
      );
    },
  );
}
