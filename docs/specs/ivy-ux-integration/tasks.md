# Tasks: Ivy UX Integration & Theme Minimalization

## 📋 Task Checklist & Dependency Waves

This specification outlines the execution checklist divided into four logical dependency waves. Waves must be verified in sequence.

---

### 🌊 Wave 1: Theme Presets & Color Cleanups
Focuses on cleaning up the unused presets, renaming/standardizing the remaining minimalist theme, and updating the color codes for both dark and light modes.

- [ ] **Task 1.1: Clean up unused presets in AppThemePreset**
  - **Files**: [theme_provider.dart](file:///c:/Codingg/duasaku_app/lib/core/theme/theme_provider.dart)
  - **Action**: Remove `rosePine` and `cyberpunk` cases from `AppThemePreset` enum and all switch cases.
  - **Verification**: Run compile check to ensure no references remain.
- [ ] **Task 1.2: Remove references in LiquidGlassTheme**
  - **Files**: [liquid_glass_theme.dart](file:///c:/Codingg/duasaku_app/lib/core/theme/liquid_glass_theme.dart)
  - **Action**: Delete factory constructors for rosePine and cyberpunk.
  - **Verification**: Code compiles without reference errors.
- [ ] **Task 1.3: Redefine defaultPurple theme colors as Minimalist**
  - **Files**: [theme_provider.dart](file:///c:/Codingg/duasaku_app/lib/core/theme/theme_provider.dart), [liquid_glass_theme.dart](file:///c:/Codingg/duasaku_app/lib/core/theme/liquid_glass_theme.dart)
  - **Action**: 
    - Set Scaffold background color in Dark Mode to `#121212` and surface/card to `#1C1C1E`.
    - Set Scaffold background color in Light Mode to `#FFFFFF` and surface/card to `#F5F5F7`.
    - Keep naming tags tidy.
  - **Verification**: Verify background colors using manual inspections on emulator in both dark and light modes.

---

### 🌊 Wave 2: Hybrid Home Screen Layout
Focuses on updating the home screen layout to include the stacked wallet layout at the top and date-grouped transactions list at the bottom.

- [ ] **Task 2.1: Group transactions by date in HomeScreen state**
  - **Files**: [home_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/presentation/screens/home_screen.dart)
  - **Action**: Implement a helper function to group retrieved transactions list by calendar date and compute aggregated balance change for each date group.
  - **Verification**: Unit test the grouping logic with sample transactions.
- [ ] **Task 2.2: Refactor UI List section**
  - **Files**: [home_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/presentation/screens/home_screen.dart)
  - **Action**: Replace the simple `SliverList` with a grouped listing using headers for each date. Render the aggregated day total in bold in the header's right corner.
  - **Verification**: Run the app and ensure the grouped layout appears visually correct, displaying aggregated values.

---

### 🌊 Wave 3: Glassmorphic Pastel Categories
Focuses on updating the category grid design inside sheets/widgets and executing final validation checks.

- [ ] **Task 3.1: Redesign Category selection grid in Transaction Draft Bottom Sheet**
  - **Files**: [transaction_draft_bottom_sheet.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/presentation/widgets/transaction_draft_bottom_sheet.dart)
  - **Action**:
    - Update container styling to apply backdrop glassmorphism.
    - Style category icons with soft pastel background circles.
    - Set item text to monochrome.
    - Add active selection glow shadows and border outlines.
  - **Verification**: Tap on category items in the sheet; verify highlight glow color matches the selected category icon's color.

---

### 🌊 Wave 4: Calculator Input & Fluid Analytics
Focuses on implementing the math parser helper, integrating it into amount text controllers, and overhauling the analytics screen with smooth curve charts.

- [ ] **Task 4.1: Implement math parser utility**
  - **Files**: [math_parser.dart](file:///c:/Codingg/duasaku_app/lib/core/utils/math_parser.dart) [NEW]
  - **Action**: Build the math parser evaluator evaluating `+`, `-`, `*`, `/` arithmetic operations on sanitized strings.
  - **Verification**: Execute test cases for evaluation (e.g. `20000+15000`, `150000-50000`, etc.) ensuring no parse crashes occur.
- [ ] **Task 4.2: Integrate calculator in amount text fields**
  - **Files**: [transaction_draft_bottom_sheet.dart](file:///c:/Codingg/duasaku_app/lib/features/transactions/presentation/widgets/transaction_draft_bottom_sheet.dart), manual transaction sheets.
  - **Action**: Listen for editing completion in amount input text fields and evaluate math strings dynamically, replacing the input value with the final sum formatted with thousands separators.
  - **Verification**: Enter mathematical formulas in fields and verify the output evaluates correctly.
- [ ] **Task 4.3: Add fluid LineChart to Financial Insights**
  - **Files**: [insights_screen.dart](file:///c:/Codingg/duasaku_app/lib/features/insights/presentation/screens/insights_screen.dart)
  - **Action**: Implement curved LineChart trends inside the screen, configuring `isCurved: true`, hiding gridlines/borders, and overlaying a fading gradient background fill beneath the line.
  - **Verification**: Open Insights screen and confirm chart looks smooth, uncluttered, and displays accurate transaction spend trend lines.
- [ ] **Task 4.4: Verify changes with checklist script**
  - **Command**: `python .agent/scripts/checklist.py .`
  - **Action**: Run the codebase verification checks.
  - **Verification**: Script execution returns success.
