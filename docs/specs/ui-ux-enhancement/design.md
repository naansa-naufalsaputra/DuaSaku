# Design Document: Premium UI/UX Enhancement

## Overview
This design document details the visual components and refactoring plan to improve the visual quality, spacing, layouts, and data entry flow across three main UI sections: the Add Transaction modal, the Transaction History screen, and the Insights dashboard.

---

## 1. Add Transaction Bottom Sheet (`TransactionTypeBottomSheet`)
*   **Path:** `lib/features/transactions/presentation/widgets/transaction_type_bottom_sheet.dart`

### Key Layout Modifications:
*   **Remove Fixed Heights:** Delete the `SizedBox(height: 350)` wrapping the `TabBarView` to eliminate nested scrolls. Use a single unified scrollable sheet structure.
*   **Segmented Transaction Type Selector:** Instead of a standard dropdown, use a sliding custom segmented selector or a two-card row (Expense vs Income) with themed backgrounds and check icons.
*   **Horizontal Wallet Cards Selector:** 
    - Replace the dropdown for wallets with a horizontal `ListView.builder` rendering mini wallet cards.
    - Each mini card displays the wallet's name, type, and balance.
    - The active wallet is highlighted with a gradient border and a glowing background indicator.
*   **Dynamic Category Chip Selector:**
    - Replace the manual category text input field with a scrollable grid/wrap of category chips.
    - Chips are populated dynamically from `ref.watch(categoryNotifierProvider)`.
    - Each chip displays the category icon and text, colored with its specific hex/default color.
    - Selection updates `_manualCategoryController.text` and sets visual active state.
*   **Tactile Feedback:** Apply `HapticFeedback.lightImpact()` on selection changes and `HapticFeedback.mediumImpact()` on submit.

---

## 2. Grouped Transaction History (`HistoryScreen`)
*   **Path:** `lib/features/transactions/presentation/screens/history_screen.dart`

### Layout Modifications:
*   **Cashflow Summary Header Widget:**
    - Build a header card above the list containing:
        - Active date range indicator.
        - Two side-by-side columns: **Income** (Green accent, green up-arrow) and **Expenses** (Red accent, red down-arrow) summing up the filtered list.
*   **Chronological Grouping Logic:**
    - Group transactions in memory using a `LinkedHashMap<String, List<TransactionModel>>` keyed by a formatted date string (e.g. "Today", "Yesterday", "25 May 2026").
    - Render the list using `ListView.builder` or a `CustomScrollView` with slivers to maintain high performance.
*   **Themed Transaction Tiles:**
    - Each tile uses a glass card styling.
    - Leading icon is wrapped in a container matching the category's custom color with 15% opacity.
    - Notes are prioritized in the main title, with the category name displayed as a small uppercase subtitle.

---

## 3. Financial Insights Polish (`InsightsScreen`)
*   **Path:** `lib/features/insights/presentation/screens/insights_screen.dart`

### Layout Modifications:
*   **Rounded Bar Rods & Glass Gradients:**
    - In `BarChart`, set `borderRadius` to `BorderRadius.vertical(top: Radius.circular(8))` for all rods.
    - Use gradient fills matching the system theme preset (e.g., Pink/Cyan for Cyberpunk, Purple/Teal for default).
*   **Category Spending Percentage List:**
    - Insert a visual breakdown card below the Pie Chart.
    - For each category, display:
        - Row with category name and formatted amount.
        - Under the row, a custom progress bar indicating the percentage of total expense.
*   **Interactive Pie Chart & Legend:**
    - Add select callback `pieTouchData: PieTouchData(...)` to expand the tapped segment slightly.
    - Format a vertical/horizontal legend with small colored dot markers.
