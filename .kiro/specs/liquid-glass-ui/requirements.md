# Requirements Document

## Introduction

Full UI/UX overhaul of the DuaSaku app to adopt a "Liquid Glass" design system — a glassmorphism aesthetic with fluid/liquid animations applied consistently across all screens and components. This replaces the current opaque card-with-border approach with translucent, blurred glass surfaces while preserving the existing 3-preset theme system (defaultPurple, rosePine, cyberpunk) and dark/light mode support.

## Glossary

- **Liquid_Glass_System**: The complete set of reusable Flutter widgets, theme extensions, and animation utilities that implement the liquid glass aesthetic across the DuaSaku app
- **Glass_Surface**: A translucent container widget that uses BackdropFilter with blur to create a frosted glass appearance over the PremiumBackground
- **Liquid_Animation**: Fluid motion effects (morphing, rippling, flowing) applied to UI elements using flutter_animate, giving the impression of liquid movement
- **Glass_Card**: A card-style widget that replaces the current opaque bordered cards with a translucent blurred surface, tinted border glow, and subtle inner highlight
- **Glass_Navigation_Bar**: The bottom navigation bar rendered as a floating glass surface with liquid-style active indicator
- **Glass_App_Bar**: The top app bar rendered as a translucent blurred surface that blends with scrollable content beneath it
- **Glass_Bottom_Sheet**: A modal or persistent bottom sheet rendered with the glass surface treatment and liquid entry animation
- **Glass_Dialog**: A dialog widget rendered with glass surface treatment and scale/fade entry animation
- **Liquid_Progress_Indicator**: A progress indicator (linear or circular) with fluid fill animation that simulates liquid flowing
- **Glass_Input_Field**: A text input field with glass surface background, glowing focus border, and subtle blur
- **Glass_Button**: A button widget with glass surface treatment, liquid press animation, and glow feedback
- **Theme_Extension**: A Flutter ThemeExtension that provides liquid glass design tokens (blur sigma, surface opacity, border glow color, animation durations) per theme preset
- **PremiumBackground**: The existing animated gradient background widget that provides the colorful backdrop behind glass surfaces
- **Blur_Sigma**: The Gaussian blur radius value applied to BackdropFilter for the frosted glass effect
- **Surface_Opacity**: The alpha transparency value of the glass surface tint color
- **Border_Glow**: A subtle colored border on glass surfaces that picks up the theme's accent color

## Requirements

### Requirement 1: Glass Theme Extension

**User Story:** As a developer, I want a centralized ThemeExtension that defines all liquid glass design tokens, so that glass styling is consistent and theme-aware across the entire app.

#### Acceptance Criteria

1. THE Liquid_Glass_System SHALL provide a ThemeExtension class containing design tokens for Blur_Sigma, Surface_Opacity, Border_Glow color, surface tint color, inner highlight opacity, and standard animation durations
2. WHEN the user switches between theme presets (defaultPurple, rosePine, cyberpunk), THE Theme_Extension SHALL provide preset-specific token values that harmonize with each preset's color palette
3. WHEN the user switches between dark and light mode, THE Theme_Extension SHALL adjust Surface_Opacity and Border_Glow values to maintain visual contrast and readability
4. THE Theme_Extension SHALL be accessible via `Theme.of(context).extension<LiquidGlassTheme>()` from any widget in the tree

### Requirement 2: Glass Surface Base Widget

**User Story:** As a developer, I want a reusable Glass_Surface widget, so that I can wrap any content in a consistent frosted glass container without duplicating BackdropFilter logic.

#### Acceptance Criteria

1. THE Glass_Surface SHALL render a BackdropFilter with configurable Blur_Sigma (default from Theme_Extension) over its child content
2. THE Glass_Surface SHALL apply a semi-transparent surface tint color derived from the current theme's colorScheme.surface with Surface_Opacity from Theme_Extension
3. THE Glass_Surface SHALL display a Border_Glow using a 1px border with the theme's primary color at reduced opacity
4. THE Glass_Surface SHALL render a subtle top-edge inner highlight (white at 5-10% opacity) to simulate light refraction
5. THE Glass_Surface SHALL use a border radius of 16px consistent with the existing design system standard
6. WHEN the Glass_Surface is placed over the PremiumBackground, THE Glass_Surface SHALL allow the animated gradient glows to be visible through the blur while ensuring the surface tint color remains dominant enough to guarantee text readability (see Requirement 14.1 for dynamic contrast constraint)

### Requirement 3: Glass Card Widget

**User Story:** As a user, I want all cards in the app to have a frosted glass appearance, so that the UI feels modern and cohesive with the liquid glass aesthetic.

#### Acceptance Criteria

1. THE Glass_Card SHALL extend Glass_Surface with additional padding (default 16px), optional onTap callback, and press animation
2. WHEN the user taps a Glass_Card, THE Glass_Card SHALL animate with a scale-down to 0.96 and a brief border glow intensification (matching existing AnimatedCard behavior)
3. THE Glass_Card SHALL replace all existing opaque Card widgets across the app's screens (transactions, wallets, goals, insights, profile, gamification, recurring_transactions, smart_budget_alerts, ai_chat)
4. WHILE the Glass_Card is in its default state, THE Glass_Card SHALL maintain minimum touch target size of 48x48dp for accessibility compliance

### Requirement 4: Glass Navigation Bar

**User Story:** As a user, I want the bottom navigation bar to have a floating glass appearance, so that it integrates visually with the liquid glass design system.

#### Acceptance Criteria

1. THE Glass_Navigation_Bar SHALL render as a floating glass surface with horizontal margin (16px) and bottom margin (12px) from screen edges
2. THE Glass_Navigation_Bar SHALL apply BackdropFilter blur to show the PremiumBackground and scrollable content beneath it
3. WHEN the user selects a navigation destination, THE Glass_Navigation_Bar SHALL animate the active indicator with a liquid morphing transition (smooth position interpolation using Curves.easeOutCubic, 300ms duration)
4. THE Glass_Navigation_Bar SHALL preserve the existing icon and label theming from each preset's NavigationBarThemeData

### Requirement 5: Glass App Bar

**User Story:** As a user, I want the app bar to blend seamlessly with content as I scroll, so that the glass effect creates a unified visual experience.

#### Acceptance Criteria

1. THE Glass_App_Bar SHALL render with a transparent background by default and transition to a blurred glass surface when content scrolls beneath it
2. WHEN content scrolls beneath the Glass_App_Bar, THE Glass_App_Bar SHALL apply BackdropFilter blur with Surface_Opacity increasing from 0 to the theme's standard value over 50px of scroll distance
3. THE Glass_App_Bar SHALL maintain the existing transparent AppBar behavior (no elevation, theme-colored icons and title)
4. THE Glass_App_Bar SHALL support both pinned and floating scroll behaviors

### Requirement 6: Glass Bottom Sheet

**User Story:** As a user, I want bottom sheets (like transaction entry) to appear with a glass surface and fluid animation, so that modal interactions feel premium and consistent.

#### Acceptance Criteria

1. THE Glass_Bottom_Sheet SHALL render its surface using Glass_Surface with increased Blur_Sigma (1.5x the standard value) for stronger frosted effect
2. WHEN the Glass_Bottom_Sheet appears, THE Glass_Bottom_Sheet SHALL animate with a slide-up combined with a subtle scale-from-0.95 and fade-in (300ms, Curves.easeOutCubic)
3. THE Glass_Bottom_Sheet SHALL display a drag handle rendered as a small glass pill (40x4px, rounded) at the top
4. THE Glass_Bottom_Sheet SHALL apply a scrim overlay (black at 40% opacity) behind it to maintain content focus

### Requirement 7: Glass Dialog

**User Story:** As a user, I want dialogs to appear with a glass surface and smooth animation, so that confirmations and alerts feel integrated with the liquid glass design.

#### Acceptance Criteria

1. THE Glass_Dialog SHALL render its surface using Glass_Surface with standard Blur_Sigma
2. WHEN the Glass_Dialog appears, THE Glass_Dialog SHALL animate with a scale-from-0.9 combined with fade-in (250ms, Curves.easeOutCubic)
3. THE Glass_Dialog SHALL display action buttons rendered as Glass_Button widgets
4. THE Glass_Dialog SHALL apply a scrim overlay (black at 50% opacity) behind it

### Requirement 8: Liquid Progress Indicators

**User Story:** As a user, I want progress indicators to animate with a liquid fill effect, so that loading and goal progress feels dynamic and alive.

#### Acceptance Criteria

1. THE Liquid_Progress_Indicator (linear variant) SHALL animate its fill with a fluid wave motion on the leading edge during progress changes
2. THE Liquid_Progress_Indicator (circular variant) SHALL animate its fill with a liquid surface wobble effect during progress changes
3. WHEN progress value changes, THE Liquid_Progress_Indicator SHALL interpolate smoothly to the new value over 400ms using Curves.easeOutCubic
4. THE Liquid_Progress_Indicator SHALL render its track as a glass surface (subtle blur and tint) and its fill with the theme's primary color at full opacity
5. THE Liquid_Progress_Indicator SHALL support both determinate (0.0-1.0 value) and indeterminate (continuous animation) modes

### Requirement 9: Glass Input Field

**User Story:** As a user, I want text input fields to have a glass background and glowing focus state, so that form interactions feel consistent with the liquid glass aesthetic.

#### Acceptance Criteria

1. THE Glass_Input_Field SHALL render its background as a Glass_Surface with reduced Blur_Sigma (0.5x standard) for subtlety
2. WHEN the Glass_Input_Field receives focus, THE Glass_Input_Field SHALL animate its Border_Glow to full primary color opacity over 200ms
3. WHEN the Glass_Input_Field loses focus, THE Glass_Input_Field SHALL animate its Border_Glow back to the default reduced opacity over 200ms
4. IF the Glass_Input_Field receives an error state, THEN THE Glass_Input_Field SHALL display the Border_Glow in the theme's error color
5. THE Glass_Input_Field SHALL maintain minimum height of 48dp and provide sufficient color contrast (4.5:1 ratio) between input text and glass background for accessibility

### Requirement 10: Glass Button

**User Story:** As a user, I want buttons to have a glass appearance with liquid press feedback, so that interactive elements feel cohesive with the design system.

#### Acceptance Criteria

1. THE Glass_Button SHALL render as a Glass_Surface with centered text/icon content
2. WHEN the user presses the Glass_Button, THE Glass_Button SHALL animate with scale-down to 0.95 and Border_Glow intensification over 100ms
3. WHEN the user releases the Glass_Button, THE Glass_Button SHALL animate back to default state over 150ms with Curves.easeOutCubic
4. THE Glass_Button SHALL support primary (filled glass with primary tint), secondary (outlined glass), and text-only (no surface, glow on press) variants
5. THE Glass_Button SHALL provide haptic feedback (light impact) on press, consistent with existing AnimatedCard behavior

### Requirement 11: Liquid Animations Utility

**User Story:** As a developer, I want a set of reusable liquid animation extensions, so that I can apply consistent fluid motion effects across widgets without reimplementing animation logic.

#### Acceptance Criteria

1. THE Liquid_Glass_System SHALL provide flutter_animate extension methods for: liquid fade-in, liquid slide-up, liquid scale-in, and liquid shimmer
2. THE Liquid_Glass_System SHALL provide a staggered list animation utility that applies liquid fade-in with configurable delay per item (default 50ms)
3. WHEN a liquid animation plays, THE Liquid_Animation SHALL use duration and curve values from the Theme_Extension to maintain consistency
4. THE Liquid_Glass_System SHALL provide a liquid page transition builder compatible with GoRouter's CustomTransitionPage

### Requirement 12: Screen Migration

**User Story:** As a user, I want all existing screens to use the liquid glass components, so that the entire app has a unified premium feel.

#### Acceptance Criteria

1. THE Liquid_Glass_System SHALL be applied to all feature screens: transactions, wallets, goals, insights, profile, gamification, recurring_transactions, smart_budget_alerts, ai_chat, and auth
2. WHEN migrating existing screens, THE Liquid_Glass_System SHALL preserve all existing functionality and data display without regression
3. THE Liquid_Glass_System SHALL ensure all migrated screens maintain the PremiumBackground as the base layer behind glass surfaces
4. WHEN a screen contains scrollable lists, THE Liquid_Glass_System SHALL apply staggered liquid animations to list items on initial load

### Requirement 13: Performance Optimization

**User Story:** As a user, I want the glass effects to run smoothly on mid-range devices, so that the premium aesthetic does not degrade the app experience.

#### Acceptance Criteria

1. THE Liquid_Glass_System SHALL limit BackdropFilter usage to a maximum of 3 simultaneous blur layers per screen to maintain 60fps rendering
2. THE Liquid_Glass_System SHALL use `RepaintBoundary` widgets around Glass_Surface instances to isolate repaint regions
3. WHEN a device exhibits frame drops below 50fps during glass rendering, THE Liquid_Glass_System SHALL provide a reduced-motion fallback that replaces blur with solid semi-transparent surfaces
4. THE Liquid_Glass_System SHALL cache blur filter results where content beneath the glass surface is static (non-scrolling contexts)
5. THE Liquid_Glass_System SHALL avoid applying BackdropFilter to list items in scrollable lists — list item Glass_Cards SHALL use solid semi-transparent backgrounds without blur for scroll performance

### Requirement 14: Accessibility Compliance

**User Story:** As a user with accessibility needs, I want the glass UI to remain readable and navigable, so that the visual effects do not impair usability.

#### Acceptance Criteria

1. THE Liquid_Glass_System SHALL maintain minimum 4.5:1 contrast ratio between text and glass surface backgrounds across all theme presets and modes, INCLUDING when the animated PremiumBackground gradient shifts color beneath the Glass_Surface. THE Surface_Opacity tint SHALL be sufficiently dominant to prevent contrast breakdown from dynamic background color changes, OR text elements on Glass_Surface SHALL include a subtle text shadow (black at 20-30% opacity, 1px offset) as a contrast safety net
2. WHEN the device has "Reduce Motion" accessibility setting enabled, THE Liquid_Glass_System SHALL disable all Liquid_Animations and use instant transitions
3. WHEN the device has "Reduce Transparency" accessibility setting enabled, THE Liquid_Glass_System SHALL increase Surface_Opacity to near-opaque (0.9+) and disable BackdropFilter blur
4. THE Liquid_Glass_System SHALL ensure all interactive glass components (Glass_Card, Glass_Button, Glass_Input_Field) have proper semantic labels for screen readers
5. THE Liquid_Glass_System SHALL maintain minimum touch target sizes of 48x48dp for all interactive glass components
