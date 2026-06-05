# Implementation Plan: Liquid Glass UI

## Overview

Full UI/UX overhaul of the DuaSaku app to adopt a "Liquid Glass" design system. Implementation follows a 4-phase approach: theme foundation → core UI kit → screen migration → quality assurance. Each phase builds incrementally on the previous, ensuring no orphaned code.

## Tasks

- [x] 1. Phase 1: Setup & Theme Foundation
  - [x] 1.1 Create LiquidGlassTheme ThemeExtension with all design tokens
    - Create `lib/core/theme/liquid_glass_theme.dart`
    - Implement `LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme>` with fields: `blurSigma`, `surfaceOpacity`, `borderGlowColor`, `surfaceTintColor`, `innerHighlightOpacity`, `animationDuration`, `animationDurationFast`, `animationDurationSlow`, `animationCurve`
    - Implement `copyWith()` and `lerp()` methods for smooth theme transitions
    - Add factory constructors for each preset/mode combination with values from the design token table
    - Add a static `of(BuildContext context)` convenience accessor
    - _Requirements: 1.1, 1.4_

  - [x] 1.2 Register extension into existing 3 presets with dark/light mode values
    - Modify `lib/core/theme/theme_provider.dart` (or equivalent preset definitions)
    - Add `LiquidGlassTheme` extension to `defaultPurple` dark and light ThemeData
    - Add `LiquidGlassTheme` extension to `rosePine` dark and light ThemeData
    - Add `LiquidGlassTheme` extension to `cyberpunk` dark and light ThemeData
    - Use preset-specific token values from the design document's data model table
    - _Requirements: 1.2, 1.3_

  - [x] 1.3 Create liquid animation utilities (flutter_animate extensions)
    - Create `lib/core/widgets/animations/liquid_animations.dart`
    - Implement `LiquidAnimateExtensions` on `Widget`: `liquidFadeIn`, `liquidSlideUp`, `liquidScaleIn`, `liquidShimmer`
    - Implement `LiquidListAnimations` on `Widget`: `liquidStagger(int index, {Duration itemDelay})`
    - Implement `liquidPageRoute<T>(Widget page)` for GoRouter `CustomTransitionPage` compatibility
    - All animations must read duration/curve from `LiquidGlassTheme` via context
    - When `MediaQuery.disableAnimations` is true, use `Duration.zero` for all animations
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 14.2_

  - [x] 1.4 Wrap PremiumBackground with RepaintBoundary for GPU isolation
    - Modify `lib/core/theme/premium_background.dart`
    - Wrap the existing `PremiumBackground` widget output with `RepaintBoundary` to isolate GPU repaint regions
    - Ensure no visual or functional regression to existing gradient animations
    - _Requirements: 13.2_

- [x] 2. Phase 2: Core UI Kit Construction
  - [x] 2.1 Build GlassSurface base widget
    - Create `lib/core/widgets/glass/glass_surface.dart`
    - Implement `GlassSurface` with `BackdropFilter` (configurable `blurSigma`), semi-transparent surface tint, 1px border glow, top-edge inner highlight, and 16px border radius
    - Add `enableBlur` parameter (default: true) — when false, render solid semi-transparent surface without BackdropFilter
    - Wrap in `RepaintBoundary` for GPU isolation
    - Read `MediaQuery.accessibleNavigation`, `boldTextOf`, `highContrastOf` to adjust opacity and disable blur per accessibility error handling rules
    - Check platform "Reduce Transparency" setting to increase opacity to 0.92 and disable blur
    - Fall back to hardcoded defaults if `LiquidGlassTheme` extension is not found (log warning in debug)
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 13.2, 13.4, 14.1, 14.3_

  - [x] 2.2 Write property tests for GlassSurface
    - **Property 1: Surface tint color derivation** — Generate random Color values and opacity doubles, verify `resultColor == surfaceColor.withOpacity(surfaceOpacity)`
    - **Property 2: Dynamic contrast guarantee** — Generate random background colors from each preset's glow palette, compute alpha-blend with surface tint, verify WCAG contrast ratio >= 4.5:1
    - **Property 6: No blur in scrollable list items** — Render GlassCard with `enableBlur: false`, verify no BackdropFilter in widget tree
    - **Validates: Requirements 2.2, 2.6, 9.5, 13.5, 14.1**
    - Create `test/properties/liquid_glass_properties_test.dart`
    - Use `glados` package, minimum 100 iterations per property

  - [x] 2.3 Build GlassCard widget
    - Create `lib/core/widgets/glass/glass_card.dart`
    - Extend GlassSurface behavior with default 16px padding, optional `onTap` callback
    - Implement tap animation: scale-down to 0.96 + border glow intensification (matching existing AnimatedCard)
    - Add `HapticFeedback.lightImpact` on press
    - Enforce minimum 48x48dp touch target via `ConstrainedBox`
    - Add `enableBlur` parameter (default: true) for list item usage
    - _Requirements: 3.1, 3.2, 3.4, 14.5_

  - [x] 2.4 Write property test for GlassCard touch target
    - **Property 7: Minimum touch target for interactive components** — Generate random child sizes (0x0 to 200x200), verify rendered hit test area >= 48x48dp
    - **Validates: Requirements 3.4, 14.5**
    - Add to `test/properties/liquid_glass_properties_test.dart`

  - [x] 2.5 Build GlassNavigationBar and GlassAppBar
    - Create `lib/core/widgets/glass/glass_navigation_bar.dart`
    - Implement floating glass bottom nav with 16px horizontal margin, 12px bottom margin
    - Add BackdropFilter blur, animated active indicator with `Curves.easeOutCubic` (300ms)
    - Preserve existing `NavigationBarThemeData` icon/label styles
    - Create `lib/core/widgets/glass/glass_app_bar.dart`
    - Implement `PreferredSizeWidget` with transparent default, scroll-reactive blur
    - Opacity formula: `clamp(scrollOffset / 50.0, 0.0, 1.0) * surfaceOpacity`
    - Support pinned and floating scroll behaviors
    - Handle null scroll controller gracefully (remain transparent)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4_

  - [x] 2.6 Write property test for GlassAppBar scroll opacity
    - **Property 3: Scroll-based opacity interpolation** — Generate random scroll offsets (0 to 1000), verify opacity = `clamp(scrollOffset / 50.0, 0.0, 1.0) * standardSurfaceOpacity`
    - **Validates: Requirements 5.2**
    - Add to `test/properties/liquid_glass_properties_test.dart`

  - [x] 2.7 Build GlassInputField and GlassButton
    - Create `lib/core/widgets/glass/glass_input_field.dart`
    - Implement glass background with 0.5x blur sigma, glowing focus border (200ms transition), error state with `colorScheme.error` border glow
    - Minimum height 48dp, ensure 4.5:1 contrast ratio
    - Support all standard TextField parameters (controller, hint, label, error, obscure, prefix/suffix icons)
    - Create `lib/core/widgets/glass/glass_button.dart`
    - Implement 3 variants: primary (filled glass + primary tint), secondary (outlined glass), text (no surface, glow on press)
    - Press animation: scale 0.95, glow intensification (100ms down, 150ms up with easeOutCubic)
    - Add `HapticFeedback.lightImpact` on press
    - Support `isLoading` state
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 2.8 Build GlassBottomSheet, GlassDialog, and LiquidProgressIndicator
    - Create `lib/core/widgets/glass/glass_bottom_sheet.dart`
    - Implement GlassSurface with 1.5x blur sigma, slide-up + scale(0.95→1.0) + fade-in entry (300ms), drag handle pill (40x4px), scrim (black 40%)
    - Add `showGlassBottomSheet<T>()` helper function
    - Create `lib/core/widgets/glass/glass_dialog.dart`
    - Implement GlassSurface with standard blur, scale(0.9→1.0) + fade-in entry (250ms), scrim (black 50%)
    - Render action buttons as GlassButton widgets
    - Add `showGlassDialog<T>()` helper function
    - Create `lib/core/widgets/glass/liquid_progress_indicator.dart`
    - Implement linear variant with fluid wave motion on leading edge
    - Implement circular variant with liquid surface wobble effect
    - Smooth interpolation over 400ms with easeOutCubic, track as glass surface, fill with primary color
    - Support determinate (0.0-1.0) and indeterminate (continuous animation) modes
    - Handle invalid values (NaN, infinity) → treat as 0.0
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 7.1, 7.2, 7.3, 7.4, 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 2.9 Write property tests for progress indicator and stagger animation
    - **Property 4: Progress value clamping** — Generate random doubles (-100 to 100), verify fill = `clamp(value, 0.0, 1.0)`, no errors for out-of-range values
    - **Property 5: Staggered animation delay computation** — Generate random (index, delay) pairs, verify delay = `index * itemDelay`, monotonically increasing
    - **Validates: Requirements 8.5, 11.2**
    - Add to `test/properties/liquid_glass_properties_test.dart`

- [x] 3. Checkpoint - Ensure all core widgets compile and tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Phase 3: Screen Migration
  - [x] 4.1 Replace all old cards with GlassCard across all screens
    - Replace existing opaque Card/AnimatedCard widgets with GlassCard in: transactions, wallets, goals, insights, profile, gamification, recurring_transactions, smart_budget_alerts, ai_chat screens
    - Use `enableBlur: false` for GlassCards inside scrollable lists (ListView, CustomScrollView) for performance
    - Preserve all existing functionality, data display, and onTap callbacks
    - Ensure PremiumBackground remains as base layer behind glass surfaces
    - _Requirements: 3.3, 12.1, 12.2, 12.3, 13.1, 13.5_

  - [x] 4.2 Replace AppBar and BottomNavigationBar with Glass versions
    - Replace all `AppBar` instances with `GlassAppBar` across all screens
    - Replace the main `BottomNavigationBar`/`NavigationBar` with `GlassNavigationBar`
    - Wire scroll controllers where applicable for scroll-reactive blur
    - Preserve existing navigation logic and routing
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3, 5.4, 12.1, 12.2_

  - [x] 4.3 Replace text fields and buttons with GlassInputField and GlassButton
    - Replace all `TextField`/`TextFormField` instances with `GlassInputField` in: auth screens, transaction entry, goal creation, AI chat input, profile editing
    - Replace all `ElevatedButton`/`OutlinedButton`/`TextButton` instances with `GlassButton` (appropriate variant)
    - Preserve all existing validation, controllers, and callbacks
    - Ensure semantic labels are maintained for screen reader accessibility
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 10.1, 10.2, 10.3, 10.4, 10.5, 12.1, 12.2, 14.4_

  - [x] 4.4 Apply staggered liquid animations to list screens
    - Add `liquidStagger` animations to list items in: transactions list, wallets list, goals list, insights list, gamification achievements, recurring transactions list
    - Apply `liquidFadeIn`/`liquidSlideUp` to screen entry transitions
    - Respect "Reduce Motion" setting (animations become instant)
    - _Requirements: 11.2, 12.4, 14.2_

- [x] 5. Checkpoint - Ensure all screen migrations work without regression
  - Ensure all tests pass, ask the user if questions arise.

- [x] 6. Phase 4: Quality Assurance
  - [x] 6.1 Test dynamic contrast (4.5:1 ratio with animated background)
    - Create `test/core/widgets/glass/glass_surface_contrast_test.dart`
    - Write widget tests that verify text contrast ratio >= 4.5:1 against all preset/mode combinations
    - Test with various simulated PremiumBackground gradient colors blended through the glass surface
    - Verify text shadow fallback provides sufficient contrast when surface opacity alone is insufficient
    - Verify `boldTextOf` and `highContrastOf` accessibility overrides increase opacity correctly
    - _Requirements: 14.1, 2.6, 9.5_

  - [x] 6.2 Write unit tests for GPU performance constraints
    - Create `test/core/widgets/glass/glass_performance_test.dart`
    - Write widget tests verifying max 3 BackdropFilter layers per screen composition
    - Verify GlassCard in scrollable list context renders without BackdropFilter
    - Verify RepaintBoundary is present around GlassSurface instances
    - Verify `enableBlur: false` path produces no BackdropFilter in widget tree
    - _Requirements: 13.1, 13.2, 13.5_

- [x] 7. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- All glass widgets use Dart/Flutter with the existing flutter_animate and glados packages
- The `enableBlur: false` pattern is critical for scroll performance — never use BackdropFilter in list items
- Existing AnimatedCard can be deprecated after full migration is complete

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "1.4"] },
    { "id": 2, "tasks": ["2.1"] },
    { "id": 3, "tasks": ["2.2", "2.3", "2.5", "2.7", "2.8"] },
    { "id": 4, "tasks": ["2.4", "2.6", "2.9", "4.1", "4.2"] },
    { "id": 5, "tasks": ["4.3", "4.4"] },
    { "id": 6, "tasks": ["6.1", "6.2"] }
  ]
}
```
