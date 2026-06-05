# Requirements Document: Premium UI/UX Enhancement (Add Sheet, History, Insights)

## Introduction
This spec outlines the comprehensive design and visual enhancement of three critical user-facing interfaces in DuaSaku:
1. **Add Transaction Bottom Sheet (`TransactionTypeBottomSheet`):** Redesigning the layout to resolve spacing issues, replace standard dropdowns with visual selectors, add a category grid/chip picker, and handle wallet states beautifully.
2. **Transaction History Screen (`HistoryScreen`):** Redesigning the list view into grouped list cards, adding a dynamic summary header, and polishing the empty/loading states.
3. **Financial Insights Screen (`InsightsScreen`):** Enhancing the charts (Bar and Pie), adding a visual category breakdown list with percentage progress bars, and polishing the Health Score gauge.

---

## Requirements

### Requirement 1: Premium Bottom Sheet for Add Transaction
1. **Interactive Keyboard Padding:** THE bottom sheet SHALL adjust its height dynamically using `MediaQuery.of(context).viewInsets.bottom` to prevent any text fields or buttons from being clipped by the system keyboard.
2. **Elimination of Standard Dropdowns:** 
   - THE standard `DropdownButtonFormField` for **Transaction Type** SHALL be replaced with a premium segmented control or custom visual card selection (e.g., matching the app's accent color).
   - THE standard `DropdownButtonFormField` for **Wallet** selection SHALL be replaced with a horizontal list of mini wallet cards showing the name, type, and current balance.
3. **Visual Category Picker:** 
   - THE manual category text input field SHALL be replaced with a scrollable category selection grid or chip list.
   - THE picker SHALL display all available categories (e.g., Food, Transport, Bills, Shopping, Salary) with their respective icons and colors.
4. **Graceful Wallet Empty/Error States:**
   - IF wallets fail to load or the user has no wallets, the bottom sheet SHALL NOT crash or display a plain text warning.
   - It SHALL display a styled warning card with an explicit "Create Wallet" button that navigates directly to the wallet management screen.
5. **Thumb-Zone Save Button:** THE "Save" CTA button SHALL be positioned at the bottom (within easy thumb reach) and feature premium tactile scale-down feedback on press.

---

### Requirement 2: Grouped & Summarized History Screen
1. **Date Grouping:** THE transaction list in `HistoryScreen` SHALL group transactions chronologically by date (e.g., "Hari ini", "Kemarin", "25 Mei 2026") with custom header labels.
2. **Cashflow Summary Header:** 
   - THE screen SHALL feature a premium summary header card at the top.
   - It SHALL display the total **Income** and total **Expense** of the currently filtered transactions (based on search query and category chips).
3. **Premium Tile Redesign:**
   - EACH transaction tile SHALL be redesigned to use custom glassmorphic cards with rounded corners.
   - The leading section SHALL display the category icon using its native category color rather than generic green/red circles.
   - Subtitle text SHALL display note snippets if available, and fallback to time of transaction if empty.
4. **Interactive Filters:** THE search field and filter chips (All, Income, Expense) SHALL animate smoothly when changing states, providing tactile vibration feedback.
5. **Interactive Empty State:**
   - IF no transactions match the query, the list SHALL display a beautiful empty state with a localized friendly message (e.g., "Tidak ada transaksi ditemukan") and a search-clear option.

---

### Requirement 3: Polished Insights Dashboard
1. **Rounded Bar Rods & Gradients:**
   - THE "Income vs Expense" bar chart SHALL use custom rounded bar rods (`borderRadius` on top edges).
   - The rods SHALL be filled with glass gradients (green for income, red for expense) matching the system theme details.
2. **Interactive Category Pie Chart:**
   - THE pie chart sections SHALL feature thin outlines, hover/selection enlargement, and clean typography.
   - It SHALL display a neat color-coded legend to represent each category.
3. **Visual Category Breakdown List:**
   - A scrollable list of spending categories SHALL be added directly below the pie chart.
   - Each category row SHALL display: the category name, total amount spent, and a horizontal progress bar indicating its percentage relative to total expenses.
4. **Animated Health Gauge:**
   - THE Health Score gauge progress indicator SHALL use a gradient stroke reflecting the score range (Green $\ge$ 80, Orange $\ge$ 50, Red $<$ 50).
   - The score text and gauge SHALL animate from 0 to the target score on page entrance.
