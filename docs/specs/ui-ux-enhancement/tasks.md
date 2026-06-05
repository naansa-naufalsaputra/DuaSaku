# Implementation Plan: Premium UI/UX Enhancement

## Tasks

* [ ] **1. Add Transaction Bottom Sheet Redesign**
  * [ ] 1.1 Remove fixed-height container constraints from `TransactionTypeBottomSheet` to support flexible sheet layout.
  * [ ] 1.2 Replace standard "Type" dropdown with a custom segmented selector (sliding button row).
  * [ ] 1.3 Replace standard "Wallet" dropdown with a horizontal mini-card selector featuring wallet names, types, balances, active border states, and custom gradient fills.
  * [ ] 1.4 Replace manual "Category" text field with a horizontal category chip picker that dynamically fetches category items from `categoryNotifierProvider`.
  * [ ] 1.5 Implement tactile vibration feedback on chip selection, wallet tap, and sheet submission.
  * [ ] 1.6 Fix "Failed to load wallets" text by logging errors and rendering a warning card with direct navigation to wallet settings.

* [ ] **2. Grouped History Screen Polish**
  * [ ] 2.1 Build a top summary card in `HistoryScreen` displaying the total income and total expense for the currently filtered set of transactions.
  * [ ] 2.2 Implement date grouping logic in the build method to split list entries by date (e.g. "Hari Ini", "Kemarin", or full date formats).
  * [ ] 2.3 Redesign tiles in `HistoryScreen` to use custom glass cards, category-specific icons, and category colors with opacity.
  * [ ] 2.4 Add smooth slide/fade micro-animations to list items on first load.

* [ ] **3. Insights Screen Polish**
  * [ ] 3.1 Update the "Income vs Expense" `BarChart` to use rounded top corners (`borderRadius: BorderRadius.vertical(top: Radius.circular(8))`) and premium color gradients.
  * [ ] 3.2 Add a Category Spending Breakdown section below the Pie Chart with styled progress bars indicating expenditure percentages.
  * [ ] 3.3 Add interactive pie segment enlargement on touch and clean up the chart legends.

* [ ] **4. Build and Verify**
  * [ ] 4.1 Run unit tests and property tests to verify that no functional regressions were introduced.
  * [ ] 4.2 Run flutter analyzer to check for clean compilation with zero warnings.

---

## Task Dependency Graph
```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4", "1.5", "1.6"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4"] },
    { "id": 2, "tasks": ["3.1", "3.2", "3.3"] },
    { "id": 3, "tasks": ["4.1", "4.2"] }
  ]
}
```
