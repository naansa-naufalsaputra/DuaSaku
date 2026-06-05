# Specification: Onboarding & Optional PIN Setup Flow - Tasks

This document tracks implementation progress step-by-step.

## 1. Task Breakdown Checklist

- [ ] **Task 1: Core Setup & Preference Storage**
  - [ ] Implement startup state checks in `AuthRepository`.
  - [ ] Create mock tests to verify dynamic initial authentication.
  - [ ] Verify compilation.

- [ ] **Task 2: Router Configuration**
  - [ ] Register `/onboarding` route in `app_router.dart`.
  - [ ] Implement redirection flow based on onboarding and PIN completion state.
  - [ ] Add unit tests verifying route selection logic.

- [ ] **Task 3: Onboarding UI - Wallet Step**
  - [ ] Create layout for Wallet count selection and customization.
  - [ ] Add validation (non-empty name, non-negative balance).
  - [ ] Integrate glassmorphism styles and haptic feedback.

- [ ] **Task 4: Onboarding UI - Category Step**
  - [ ] Create layout displaying default categories (Food, Transport, Salary, Bills, Shopping).
  - [ ] Allow selection and color/icon customization.

- [ ] **Task 5: Onboarding UI - PIN Step**
  - [ ] Create layout for PIN entry and verification (numpad + dots indicator).
  - [ ] Implement "Skip Security" button.
  - [ ] Implement confirmation state logic.

- [ ] **Task 6: Final Integration & Data Persistence**
  - [ ] Implement DB insertion commands on Onboarding submission.
  - [ ] Save preference states.
  - [ ] Verify full onboarding integration.

---

## 2. Dependency Waves

```
Wave 1: Task 1 (Auth State) & Task 2 (Router Configuration)
  └─ Wave 2: Task 3 (Wallet Step) & Task 4 (Category Step)
       └─ Wave 3: Task 5 (PIN Step)
            └─ Wave 4: Task 6 (DB Sync & Final Integration)
```
