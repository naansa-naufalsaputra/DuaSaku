import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/liquid_glass_theme.dart';

// ---------------------------------------------------------------------------
// Fallback defaults when LiquidGlassTheme extension is not found in theme.
// ---------------------------------------------------------------------------
const double _kDefaultBlurSigma = 12.0;
const double _kDefaultSurfaceOpacity = 0.65;
const Color _kDefaultBorderGlowColor = Color(0x4D4D8DFE);
const Color _kDefaultSurfaceTintColor = Color(0xFF161515);

/// A scroll-reactive glass app bar that transitions from fully transparent
/// to a blurred glass surface as the user scrolls.
///
/// Opacity formula: `clamp(scrollOffset / 50.0, 0.0, 1.0) * surfaceOpacity`
///
/// When [scrollController] is null, the app bar remains fully transparent.
///
/// Implements [PreferredSizeWidget] with height of [kToolbarHeight].
class GlassAppBar extends StatefulWidget implements PreferredSizeWidget {
  /// The primary widget displayed in the app bar (typically a Text widget).
  final Widget? title;

  /// Widgets to display after the title (e.g., action buttons).
  final List<Widget>? actions;

  /// Widget to display before the title (e.g., back button).
  final Widget? leading;

  /// Whether the app bar should remain visible at the top of the scroll view.
  final bool pinned;

  /// Whether the app bar should become visible as soon as the user scrolls
  /// towards the app bar.
  final bool floating;

  /// The scroll controller to listen to for opacity changes.
  /// When null, the app bar remains fully transparent.
  final ScrollController? scrollController;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.pinned = true,
    this.floating = false,
    this.scrollController,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<GlassAppBar> createState() => _GlassAppBarState();
}

class _GlassAppBarState extends State<GlassAppBar> {
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _attachScrollListener();
  }

  @override
  void didUpdateWidget(covariant GlassAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollListener(oldWidget.scrollController);
      _attachScrollListener();
    }
  }

  @override
  void dispose() {
    _detachScrollListener(widget.scrollController);
    super.dispose();
  }

  void _attachScrollListener() {
    final controller = widget.scrollController;
    if (controller != null) {
      controller.addListener(_onScroll);
      // Initialize with current offset if controller already has clients
      if (controller.hasClients) {
        _scrollOffset = controller.offset;
      }
    }
  }

  void _detachScrollListener(ScrollController? controller) {
    controller?.removeListener(_onScroll);
  }

  void _onScroll() {
    final newOffset = widget.scrollController?.offset ?? 0.0;
    if (newOffset != _scrollOffset) {
      setState(() {
        _scrollOffset = newOffset;
      });
    }
  }

  /// Computes the glass opacity based on scroll offset.
  ///
  /// Formula: clamp(scrollOffset / 50.0, 0.0, 1.0) * surfaceOpacity
  double _computeOpacity(double surfaceOpacity) {
    if (widget.scrollController == null) return 0.0;
    final scrollFactor = (_scrollOffset / 50.0).clamp(0.0, 1.0);
    return scrollFactor * surfaceOpacity;
  }

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;

    final resolvedBlurSigma = glassTheme?.blurSigma ?? _kDefaultBlurSigma;
    final resolvedSurfaceOpacity =
        glassTheme?.surfaceOpacity ?? _kDefaultSurfaceOpacity;
    final borderGlowColor =
        glassTheme?.borderGlowColor ?? _kDefaultBorderGlowColor;
    final surfaceTintColor =
        glassTheme?.surfaceTintColor ?? _kDefaultSurfaceTintColor;

    final opacity = _computeOpacity(resolvedSurfaceOpacity);
    final showGlass = opacity > 0.0;

    // Build the app bar content
    final content = SafeArea(
      bottom: false,
      child: SizedBox(
        height: kToolbarHeight,
        child: NavigationToolbar(
          leading: widget.leading ??
              (Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null),
          middle: widget.title != null
              ? DefaultTextStyle(
                  style: appBarTheme.titleTextStyle ??
                      theme.textTheme.titleLarge ??
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  child: widget.title!,
                )
              : null,
          trailing: widget.actions != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.actions!,
                )
              : null,
          centerMiddle: true,
          middleSpacing: NavigationToolbar.kMiddleSpacing,
        ),
      ),
    );

    // When no glass effect needed, render transparent
    if (!showGlass) {
      return Container(
        color: Colors.transparent,
        child: content,
      );
    }

    // Render glass surface with blur
    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: resolvedBlurSigma * (opacity / resolvedSurfaceOpacity),
            sigmaY: resolvedBlurSigma * (opacity / resolvedSurfaceOpacity),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: surfaceTintColor.withValues(alpha: opacity),
              border: Border(
                bottom: BorderSide(
                  color: borderGlowColor.withValues(
                    alpha: (borderGlowColor.a * (opacity / resolvedSurfaceOpacity)),
                  ),
                  width: 1.0,
                ),
              ),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
