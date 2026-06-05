import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/liquid_glass_theme.dart';

// ---------------------------------------------------------------------------
// Fallback defaults when LiquidGlassTheme extension is not found in theme.
// ---------------------------------------------------------------------------
const double _kDefaultBlurSigma = 12.0;
const double _kDefaultSurfaceOpacity = 0.65;
const Color _kDefaultBorderGlowColor = Color(0x4D4D8DFE); // primary@0.3
const Color _kDefaultSurfaceTintColor = Color(0xFF161515);
const double _kDefaultInnerHighlightOpacity = 0.08;

/// A floating glass bottom navigation bar that renders as a translucent
/// blurred surface with animated active indicator.
///
/// Features:
/// - 16px horizontal margin, 12px bottom margin (floating effect)
/// - BackdropFilter blur using theme's blurSigma
/// - Animated active indicator (300ms, Curves.easeOutCubic)
/// - Preserves existing NavigationBarThemeData icon/label styles
class GlassNavigationBar extends StatelessWidget {
  /// The currently selected destination index.
  final int selectedIndex;

  /// Callback when a destination is selected.
  final ValueChanged<int> onDestinationSelected;

  /// The navigation destinations to display.
  final List<NavigationDestination> destinations;

  const GlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  @override
  Widget build(BuildContext context) {
    final glassTheme = LiquidGlassTheme.of(context);
    final navBarTheme = Theme.of(context).navigationBarTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final resolvedBlurSigma = glassTheme?.blurSigma ?? _kDefaultBlurSigma;
    final resolvedSurfaceOpacity =
        glassTheme?.surfaceOpacity ?? _kDefaultSurfaceOpacity;
    final borderGlowColor =
        glassTheme?.borderGlowColor ?? _kDefaultBorderGlowColor;
    final surfaceTintColor =
        glassTheme?.surfaceTintColor ?? _kDefaultSurfaceTintColor;
    final innerHighlightOpacity =
        glassTheme?.innerHighlightOpacity ?? _kDefaultInnerHighlightOpacity;

    final borderRadius = BorderRadius.circular(24.0);

    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 12.0,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: resolvedBlurSigma,
              sigmaY: resolvedBlurSigma,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceTintColor.withValues(
                  alpha: resolvedSurfaceOpacity,
                ),
                borderRadius: borderRadius,
                border: Border.all(
                  color: borderGlowColor,
                  width: 1.0,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Inner highlight
                  Container(
                    height: 1.0,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24.0),
                        topRight: Radius.circular(24.0),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white
                              .withValues(alpha: innerHighlightOpacity),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                  // Navigation items with animated indicator
                  _GlassNavContent(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: destinations,
                    navBarTheme: navBarTheme,
                    colorScheme: colorScheme,
                    glassTheme: glassTheme,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassNavContent extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final NavigationBarThemeData navBarTheme;
  final ColorScheme colorScheme;
  final LiquidGlassTheme? glassTheme;

  const _GlassNavContent({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.navBarTheme,
    required this.colorScheme,
    required this.glassTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / destinations.length;

          return Stack(
            children: [
              // Animated active indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: selectedIndex * itemWidth + itemWidth * 0.2,
                top: 0,
                width: itemWidth * 0.6,
                height: 3.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                ),
              ),
              // Destination items
              Row(
                children: List.generate(destinations.length, (index) {
                  final destination = destinations[index];
                  final isSelected = index == selectedIndex;

                  // Resolve icon theme from NavigationBarThemeData
                  final iconThemeData = navBarTheme.iconTheme;
                  final resolvedIconTheme = iconThemeData?.resolve(
                    isSelected
                        ? {WidgetState.selected}
                        : <WidgetState>{},
                  );

                  // Resolve label style from NavigationBarThemeData
                  final labelStyleData = navBarTheme.labelTextStyle;
                  final resolvedLabelStyle = labelStyleData?.resolve(
                    isSelected
                        ? {WidgetState.selected}
                        : <WidgetState>{},
                  );

                  final icon = isSelected
                      ? (destination.selectedIcon ?? destination.icon)
                      : destination.icon;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDestinationSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconTheme(
                              data: resolvedIconTheme ??
                                  IconThemeData(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                    size: isSelected ? 26 : 24,
                                  ),
                              child: icon,
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              destination.label,
                              style: resolvedLabelStyle ??
                                  TextStyle(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
