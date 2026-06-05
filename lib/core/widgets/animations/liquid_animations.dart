import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../theme/liquid_glass_theme.dart';

// ---------------------------------------------------------------------------
// Default fallback values when LiquidGlassTheme is not registered.
// ---------------------------------------------------------------------------

const Duration _kDefaultDuration = Duration(milliseconds: 300);
const Curve _kDefaultCurve = Curves.easeOutCubic;

// ---------------------------------------------------------------------------
// Internal wrapper widget that provides BuildContext for theme-aware animations.
// ---------------------------------------------------------------------------

/// A wrapper that reads [LiquidGlassTheme] from context and passes resolved
/// duration/curve to the animation builder. Respects "Reduce Motion" setting.
class _LiquidAnimationWrapper extends StatelessWidget {
  const _LiquidAnimationWrapper({
    required this.child,
    required this.builder,
  });

  final Widget child;
  final Widget Function(
    BuildContext context,
    Widget child,
    Duration duration,
    Curve curve,
  ) builder;

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final duration = reduceMotion
        ? Duration.zero
        : (glassTheme?.animationDuration ?? _kDefaultDuration);
    final curve = glassTheme?.animationCurve ?? _kDefaultCurve;

    return builder(context, child, duration, curve);
  }
}

// ---------------------------------------------------------------------------
// LiquidAnimateExtensions — individual animation effects on Widget.
// ---------------------------------------------------------------------------

/// Provides liquid-style animation extension methods on [Widget].
///
/// Each method wraps the widget in a theme-aware animation that reads
/// duration and curve from [LiquidGlassTheme]. When the device has
/// "Reduce Motion" enabled, all durations become [Duration.zero].
extension LiquidAnimateExtensions on Widget {
  /// Fades the widget in with a liquid feel.
  Widget liquidFadeIn({Duration? delay}) {
    final target = this;
    return _LiquidAnimationWrapper(
      child: target,
      builder: (context, child, duration, curve) {
        return child
            .animate()
            .fadeIn(
              duration: duration,
              curve: curve,
              delay: delay ?? Duration.zero,
            );
      },
    );
  }

  /// Slides the widget up from below with a liquid feel.
  Widget liquidSlideUp({Duration? delay}) {
    final target = this;
    return _LiquidAnimationWrapper(
      child: target,
      builder: (context, child, duration, curve) {
        return child
            .animate()
            .fadeIn(
              duration: duration,
              curve: curve,
              delay: delay ?? Duration.zero,
            )
            .slideY(
              begin: 0.15,
              end: 0.0,
              duration: duration,
              curve: curve,
              delay: delay ?? Duration.zero,
            );
      },
    );
  }

  /// Scales the widget in from a smaller size with a liquid feel.
  Widget liquidScaleIn({Duration? delay}) {
    final target = this;
    return _LiquidAnimationWrapper(
      child: target,
      builder: (context, child, duration, curve) {
        return child
            .animate()
            .fadeIn(
              duration: duration,
              curve: curve,
              delay: delay ?? Duration.zero,
            )
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1.0, 1.0),
              duration: duration,
              curve: curve,
              delay: delay ?? Duration.zero,
            );
      },
    );
  }

  /// Applies a subtle shimmer effect with a liquid feel.
  Widget liquidShimmer({Duration? delay}) {
    final target = this;
    return _LiquidAnimationWrapper(
      child: target,
      builder: (context, child, duration, curve) {
        return child
            .animate()
            .shimmer(
              duration: duration,
              curve: curve,
              delay: delay ?? Duration.zero,
            );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// LiquidListAnimations — staggered list animation utility.
// ---------------------------------------------------------------------------

/// Provides staggered animation for list items.
///
/// Combines [liquidFadeIn] + [liquidSlideUp] with a computed delay based on
/// the item's [index] in the list.
extension LiquidListAnimations on Widget {
  /// Applies a staggered fade-in + slide-up animation.
  ///
  /// The delay for this item is computed as `index * itemDelay`.
  /// Delays are monotonically increasing across list indices.
  Widget liquidStagger(
    int index, {
    Duration itemDelay = const Duration(milliseconds: 50),
  }) {
    final computedDelay = itemDelay * index;
    final target = this;
    return _LiquidAnimationWrapper(
      child: target,
      builder: (context, child, duration, curve) {
        return child
            .animate()
            .fadeIn(
              duration: duration,
              curve: curve,
              delay: computedDelay,
            )
            .slideY(
              begin: 0.15,
              end: 0.0,
              duration: duration,
              curve: curve,
              delay: computedDelay,
            );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// liquidPageRoute — GoRouter CustomTransitionPage compatible route builder.
// ---------------------------------------------------------------------------

/// Creates a [CustomTransitionPage] route with a liquid fade + slide transition.
///
/// Compatible with GoRouter's page-based routing. Reads animation duration and
/// curve from [LiquidGlassTheme] via the transition's [BuildContext]. Respects
/// "Reduce Motion" accessibility setting.
///
/// Usage with GoRouter:
/// ```dart
/// GoRoute(
///   path: '/details',
///   pageBuilder: (context, state) => liquidPageRoute<void>(
///     const DetailsScreen(),
///   ),
/// )
/// ```
Page<T> liquidPageRoute<T>(Widget page) {
  return CustomTransitionPage<T>(
    child: page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final glassTheme = LiquidGlassTheme.of(context);
      final reduceMotion = MediaQuery.of(context).disableAnimations;
      final curve = glassTheme?.animationCurve ?? _kDefaultCurve;

      if (reduceMotion) {
        // Instant transition — no animation.
        return child;
      }

      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
      );

      return FadeTransition(
        opacity: curvedAnimation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.05),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        ),
      );
    },
    transitionDuration: _kDefaultDuration,
    reverseTransitionDuration: _kDefaultDuration,
  );
}
