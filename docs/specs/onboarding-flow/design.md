# Specification: Onboarding & Optional PIN Setup Flow - Design

## 1. Routing Architecture

GoRouter redirect logic in `app_router.dart` will be modified to support `/onboarding`:

```mermaid
graph TD
    A[App Start] --> B{Onboarding Completed?}
    B -- No --> C[Redirect to /onboarding]
    B -- Yes --> D{Is Authenticated?}
    D -- Yes --> E[Proceed to /home]
    D -- No --> F{Is PIN Set?}
    F -- Yes --> G[Redirect to /pin-auth]
    F -- No --> H[Auto Authenticate & Proceed to /home]
```

### Route Registration
* `/onboarding`: Points to `OnboardingScreen`. It is a root route (not nested in StatefulShellRoute).

---

## 2. Onboarding Screen Data Pipeline

```mermaid
sequenceDiagram
    participant UI as OnboardingScreen
    participant VM as OnboardingNotifier (StateNotifier/Notifier)
    participant DB as AppDatabase (Drift)
    participant SEC as AuthRepository (Secure Storage)
    participant SP as SharedPreferences

    UI->>VM: Start onboarding
    UI->>VM: Submit Wallets configuration
    UI->>VM: Submit Categories configuration
    UI->>VM: Set or Skip PIN
    VM->>DB: Insert Wallets & Categories
    alt PIN is set
        VM->>SEC: Write PIN hash (setPin)
    else PIN skipped
        VM->>SEC: authenticateLocally()
    end
    VM->>SP: Set onboarding_completed = true
    VM->>UI: Navigation trigger to /home
```

---

## 3. Storage & State Configurations

### SharedPreferences
* Key: `onboarding_completed` (bool)
  * `false` or missing: Needs onboarding.
  * `true`: Onboarding has been completed.

### AuthRepository Startup Check
On construction, `AuthRepository` will check the status of onboarding and PIN setup:
```dart
Future<void> checkInitialState() async {
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
  final hasPin = await hasPinSet();
  
  if (onboardingDone && !hasPin) {
    _isAuthenticated = true;
    _currentUser = User(id: AppConstants.defaultUserId, email: AppConstants.defaultUserEmail);
    notifyListeners();
  }
}
```

---

## 4. UI Layout & Component Styling
* **Overlay**: Use `PremiumBackground` as the canvas.
* **Containers**: Glassmorphism rounded boxes with border highlighting.
* **Interactive Elements**: Large buttons (48dp target) with micro-animations and haptic vibration feedback.
