# Specification: Onboarding & Optional PIN Setup Flow - Requirements

## 1. Functional Requirements

### 1.1 First Launch Detection
* The app must detect if it is being launched for the first time by checking a preference key (`onboarding_completed`) in local persistent storage (`SharedPreferences`).
* If `onboarding_completed` is false or missing, the user must be redirected to the onboarding flow immediately.

### 1.2 Wallet Configuration (Step 1)
* The user must be asked how many wallets they want to create (default is 1, maximum is 5).
* For each wallet, the user must be able to customize:
  * Name (e.g. cash, bank, etc.)
  * Type (Bank, E-Wallet, Cash)
  * Starting Balance (numeric, non-negative, default is 0)
* The app must validate that at least one wallet is defined with a valid name.

### 1.3 Category Setup (Step 2)
* The app should present a default list of categories (Food, Transport, Salary, Bills, Shopping).
* The user must be allowed to customize them (enable/disable, change name/color).

### 1.4 Optional PIN Setup (Step 3)
* The user should be given the option to secure the app with a 4-digit PIN.
* The screen must clearly present a "Skip" or "Later" button.
* If a PIN is entered, the app must ask for confirmation (re-enter PIN) to ensure no typos.
* If skipped, the app will function without any lock screen on startup.

### 1.5 Setup Completion
* On clicking "Finish", the app must:
  * Save all configured wallets and categories to the local SQLite (Drift) database.
  * If a PIN was configured, hash it and store it in `FlutterSecureStorage`.
  * Save `onboarding_completed = true` in SharedPreferences.
  * Mark the user as authenticated and navigate to the `/home` route.

---

## 2. Non-Functional & UI Requirements
* **Aesthetics**: Follow the DuaSaku premium design guidelines (glassmorphism overlays, custom gradients, smooth slide animations via `flutter_animate`, and tactile haptic feedback).
* **Responsiveness**: All input fields and layout buttons must fit on standard screen sizes and support keyboard safe inset padding.
* **Error Handling**: Graceful validation messages on empty names, negative balances, and mismatched PIN codes.
