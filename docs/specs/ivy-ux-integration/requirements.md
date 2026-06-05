# Requirements: Ivy UX Integration & Theme Minimalization

## 1. Introduction
This document defines the requirements for integrating UI/UX elements inspired by Ivy Wallet and Apple's design language into the DuaSaku app. It covers updating the color presets (adopting a premium Dark Gray for Dark Mode and a clean Apple-style Light Mode), removing the Cyberpunk and Rose Pine presets to focus on a single premium Minimalist design system, maintaining our offline IDR-only transaction architecture, and integrating an amount input calculator and fluid analytics chart overhaul.

## 2. Goals & Scope
- **Premium Dark Gray Dark Mode**: Upgrade the Dark Mode theme to use a soft, modern dark gray surface system (e.g., #121212 base) instead of pure black (#000000) or dark brown-gray to keep it premium and gentle on the eyes.
- **Apple-Style Light Mode**: Redesign the Light Mode to be cool, airy, and minimalist, utilizing pure white backgrounds (#FFFFFF), light gray elements (#F5F5F7), generous padding, and subtle elevations/borders.
- **Theme Minimalization**: Decommission the "Cyberpunk" and "Rose Pine" theme options from the codebase, leaving only the "Minimalist" (Default/Purple variant) theme with its upgraded Light and Dark modes.
- **IDR-Only Optimization**: Keep the application strictly optimized around Indonesian Rupiah (IDR) and offline operation. Drop all consideration for multi-currency databases or converters.
- **Hybrid Main Layout**: Retain DuaSaku's signature tilting/stacked wallets visual hero element at the top, and integrate a date-grouped transaction history feed with daily totals at the bottom.
- **Pastel Glassmorphic Categories**: Overhaul the category selection grid in the transaction draft bottom sheet and other category screens to use transparent glass backgrounds and soft pastel circular icons.
- **Integrated Amount Calculator**: Build a mathematical expression parser directly inside the transaction amount field so users can evaluate simple equations on the fly.
- **Fluid Charts Analytics**: Overhaul the financial insights chart to feel exceptionally clean, modern, and fluid by removing grid noise and adding soft gradient curves.

---

## 3. Detailed Requirements

### 3.1 Theme Presets & Color Systems
- **Req 3.1.1 (Dark Mode Background)**: The dark mode scaffold background color MUST be set to a sleek dark gray (e.g., `#121212`). Secondary card surfaces MUST resolve to a slightly lighter gray (e.g., `#1C1C1E` or `#181818`) to establish visual hierarchy.
- **Req 3.1.2 (Apple Light Mode)**: The light mode scaffold background color MUST be set to pure white (`#FFFFFF`). Fills for inputs, cards, or unselected elements MUST use a soft gray (`#F5F5F7` or `#F6F6F9`). Border shadows must be ultra-subtle.
- **Req 3.1.3 (Decommission Cyberpunk & Rose Pine)**: The available choices in the theme preset settings MUST be restricted to the core Minimalist theme. The cyberpunk and rosePine assets, palettes, and configurations inside `theme_provider.dart` and `theme_provider` enum/extensions MUST be removed completely.
- **Req 3.1.4 (Typography & Contrast)**: Typography must use clean hierarchy, bold daily headers, and high-contrast text ratios conforming to WCAG AA requirements on both light and dark screens.

### 3.2 Main Layout & Navigation
- **Req 3.2.1 (The Hybrid Layout)**: The home screen MUST display the Apple Wallet-style stacked card deck (`_WalletStackedLayout`) at the top.
- **Req 3.2.2 (Date-Grouped Transaction Feed)**: Beneath the card stack, recent transactions MUST be grouped by date (e.g., "Hari Ini", "Kemarin", or date format like "2 Juni 2026").
- **Req 3.2.3 (Daily Aggregate Header)**: Each date group header MUST display the aggregated net balance change of that day (total income minus total expense) formatted in bold in the top-right corner of the group header.

### 3.3 Transaction Draft Sheet & Categories
- **Req 3.3.1 (Glassmorphic pastel category grid)**: The category grid inside the transaction draft sheet MUST be styled using BackdropFilter or semi-transparent backgrounds to simulate frosted glass.
- **Req 3.3.2 (Pastel Icons)**: Icons representing categories must be enclosed in circular backgrounds using soft pastel tones.
- **Req 3.3.3 (Active Glow Selection)**: Selecting a category chip MUST show a distinct, colored border and a subtle glowing container/shadow using the selected category's pastel theme color.

### 3.4 Currency & Offline Operations
- **Req 3.4.1 (IDR Lock)**: Currency formatting must remain locked to Indonesian Rupiah (IDR). No multi-currency options, inputs, or conversion services should be added.
- **Req 3.4.2 (Offline Mode)**: The application MUST perform transaction creation and local SQLite (Drift) parsing fully offline without network dependencies.

### 3.5 Integrated Input Calculator (Amount Field)
- **Req 3.5.1 (Math Expression Parsing)**: The transaction amount field (both on draft dialogs and manual transaction sheets) MUST accept mathematical expressions containing numbers and basic arithmetic operators (`+`, `-`, `*`, `/`).
- **Req 3.5.2 (Real-Time or Submit Evaluation)**: The expression MUST evaluate to a final single numeric value either dynamically as the user types (with preview) or automatically when the text field loses focus / the form is submitted.
- **Req 3.5.3 (Formatting Coexistence)**: The custom mathematical parsing engine MUST coordinate with our existing thousands separator formatting utility without throwing errors or corrupting raw numeric inputs.

### 3.6 Visual Analytics Overhaul (Fluid Charts)
- **Req 3.6.1 (Clean Layout)**: Chart presentations on the insights screen MUST remove all cluttered gridlines, vertical/horizontal division guides, and hard boundary boxes.
- **Req 3.6.2 (Fluid Trend Curve)**: The financial trend chart MUST display spending histories as a smooth, curved line (`isCurved: true`) using a custom bezier curve interpolation to look elegant.
- **Req 3.6.3 (Fading Accent Gradient)**: The area below the trend line MUST be filled with a vertical linear gradient starting from the theme's primary accent color at `30%` opacity at the top edge, fading smoothly down to `0%` opacity at the bottom edge.
