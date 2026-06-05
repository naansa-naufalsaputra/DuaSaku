# Requirements — Wallet Redesign and Security Bug Fixes

## 1. Functional Requirements

### 1.1 Home Screen Wallets Redesign
- The current horizontal `PageView` for wallets must be replaced with a stacked cards layout (Apple Wallet style).
- The front card must show the **Total Balance** across all wallets.
- Individual wallet cards are stacked behind the front card. Only the top header portion of each card (wallet name and balance) must peek out.
- Tapping a wallet card must trigger a smooth transition animation (expanding or sliding out) and navigate to that wallet's detail screen.

### 1.2 Wallet Detail Screen
- A new screen must be created at `/wallets/:walletId` displaying:
  - Wallet details (name, type, current balance).
  - Transaction history specifically filtered for this wallet (income, expense, and transfers).
  - Empty state when no transactions exist.

### 1.3 Quick Action Row
- The text truncation inside the action items ("New Transaction", "Manage Wallets", etc.) must be resolved.
- Text must be allowed to wrap onto up to two lines (`maxLines: 2`).
- All action items in the row must share the same height dynamically using `IntrinsicHeight`.

### 1.4 Component Layout Reordering
- The "Savings Goals" dashboard widget must be relocated from the bottom of the page to directly beneath the "Smart Input" card.

### 1.5 Total Balance Discrepancy
- The Assets card on the Home Screen must calculate the user's total balance as the sum of all wallet balances (`wallet.balance`), rather than summing all transactions (which is initially zero).

### 1.6 Onboarding Security Bypass
- The security lock screen (`PinAuthScreen`) must never intercept navigation or display biometric prompts while the user is still in the onboarding flow (`isOnboardingCompleted` is false).

## 2. Acceptance Criteria
- [ ] Onboarding runs smoothly without being interrupted by the security PIN screen.
- [ ] Total balance displays the correct sum of all initial wallet balances immediately after onboarding.
- [ ] The wallets stacked layout displays horizontal cards overlapping vertically, showing names and balances on the peek area.
- [ ] Tapping a wallet card plays a sliding animation and navigates to the wallet's transaction history.
- [ ] Action item text is wrapped and fully visible without any truncation.
- [ ] Savings goals widget is located directly beneath the Smart Input widget.
