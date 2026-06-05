# Tasks — Wallet Redesign and Security Bug Fixes

Checklist for implementing the redesign and security bug fixes.

- [x] **Security fixes**
  - [x] Modify `SecurityWrapper` in `lib/main.dart` to bypass the lock screen when `isOnboardingCompleted` is false.
  
- [x] **Navigation updates**
  - [x] Add the `/wallets/:walletId` route to `lib/core/routing/app_router.dart`.

- [x] **New Component: Wallet Detail Screen**
  - [x] Create `lib/features/wallets/presentation/screens/wallet_detail_screen.dart`
  - [x] Implement responsive layout, theme adaptation, back navigation.
  - [x] Implement filtered transaction lists for income/expense/transfer.

- [x] **Home Screen Redesign & Adjustments**
  - [x] Update `HomeScreen` total balance to sum all wallet balances instead of using `_calculateTotalAssets(txs)`.
  - [x] Create `_WalletStackedLayout` replacing `_TiltedWalletPageView` with the horizontal landscape cards stack.
  - [x] Animate card expand and push details screen when clicked.
  - [x] Set `IntrinsicHeight` on quick action `Row` and set `maxLines: 2` on labels to fix truncation.
  - [x] Move "Savings Goals" sliver directly below "Smart Input".

- [x] **Verification & Testing**
  - [x] Verify onboarding flow doesn't show any locking mechanisms.
  - [x] Verify total assets displays initial wallet balances correctly.
  - [x] Verify visual stack layout, text wrapping, and click opening animations.
  - [x] Verify detail screen transaction lists.
