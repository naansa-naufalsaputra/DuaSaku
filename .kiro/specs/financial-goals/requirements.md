# Requirements Document

## Introduction

Financial Goals (Savings Target) adalah fitur tabungan dengan target dan progress bar untuk aplikasi DuaSaku. Fitur ini memungkinkan pengguna menetapkan target keuangan (misalnya liburan, gadget, dana darurat), melacak progres tabungan secara visual, dan mendapatkan reward dari gamification system yang sudah ada saat mencapai milestone tertentu. Fitur ini mendukung deposit manual maupun tracking otomatis dari saldo wallet yang di-link.

## Glossary

- **Goal_System**: Modul yang mengelola pembuatan, penyimpanan, dan pelacakan financial goals pengguna
- **Goal**: Entitas tabungan dengan nama, target amount, deadline, dan progres saat ini
- **Goal_Repository**: Komponen data layer yang menangani operasi CRUD goal ke database lokal (Drift)
- **Goal_Notifier**: Riverpod AsyncNotifier yang mengelola state daftar goals dan mutasi
- **Deposit**: Penambahan dana ke goal, baik secara manual maupun otomatis dari wallet
- **Milestone**: Titik pencapaian persentase tertentu dari target goal (25%, 50%, 75%, 100%)
- **Progress_Bar**: Widget visual yang menampilkan persentase pencapaian goal
- **Gamification_System**: Sistem badge dan health score yang sudah ada di aplikasi
- **Linked_Wallet**: Wallet yang diasosiasikan dengan goal untuk tracking saldo otomatis
- **Notification_Service**: Layanan notifikasi lokal menggunakan flutter_local_notifications

## Requirements

### Requirement 1: Goal Creation

**User Story:** As a user, I want to create a financial goal with a name, target amount, deadline, icon, color, and linked wallet, so that I can plan and track my savings targets.

#### Acceptance Criteria

1. WHEN the user submits a valid goal form, THE Goal_System SHALL create a new goal with the provided name, target amount, optional deadline, icon, color, and optional linked wallet
2. THE Goal_System SHALL validate that the goal name has a length between 1 and 100 characters
3. THE Goal_System SHALL validate that the target amount is a positive number greater than zero
4. IF the user provides a deadline that is in the past, THEN THE Goal_System SHALL reject the goal creation and display a validation error
5. THE Goal_System SHALL assign a unique identifier to each created goal
6. WHEN a goal is created without a linked wallet, THE Goal_System SHALL set the goal tracking mode to manual deposits only
7. WHEN a goal is created with a linked wallet, THE Goal_System SHALL set the goal tracking mode to automatic wallet balance tracking
8. THE Goal_System SHALL persist the created goal to the local Drift database immediately upon creation

### Requirement 2: Goal Listing and Detail View

**User Story:** As a user, I want to see all my financial goals with their progress, so that I can monitor my savings at a glance.

#### Acceptance Criteria

1. THE Goal_System SHALL display all active goals sorted by creation date (newest first)
2. THE Goal_System SHALL display for each goal: name, current amount, target amount, progress percentage, and remaining days until deadline
3. WHEN a goal has a deadline, THE Goal_System SHALL calculate and display the number of remaining days
4. WHEN a goal has no deadline, THE Goal_System SHALL display the goal without a deadline indicator
5. WHEN the user taps on a goal, THE Goal_System SHALL navigate to a detail screen showing full goal information and deposit history

### Requirement 3: Manual Deposit to Goal

**User Story:** As a user, I want to manually add deposits to my goal, so that I can track savings contributions that are not linked to a specific wallet.

#### Acceptance Criteria

1. WHEN the user submits a deposit amount for a goal, THE Goal_System SHALL add the deposit amount to the goal current amount
2. THE Goal_System SHALL validate that the deposit amount is a positive number greater than zero
3. THE Goal_System SHALL record each deposit with the amount, date, and optional note
4. IF a deposit would cause the current amount to exceed the target amount, THEN THE Goal_System SHALL cap the current amount at the target amount and the excess amount SHALL NOT be recorded (over-funding is not permitted)
5. WHEN a deposit is recorded, THE Goal_System SHALL persist the updated goal amount and deposit record to the local database

### Requirement 4: Automatic Wallet Balance Tracking

**User Story:** As a user, I want to link a wallet to my goal so that the goal progress automatically reflects the wallet balance, so that I do not need to manually update my savings progress.

#### Acceptance Criteria

1. WHILE a goal has a linked wallet, THE Goal_System SHALL synchronize the goal current amount with the linked wallet balance
2. WHEN the linked wallet balance changes due to a transaction, THE Goal_System SHALL update the goal current amount to match the new wallet balance
3. IF the linked wallet is deleted, THEN THE Goal_System SHALL switch the goal tracking mode to manual and retain the last known amount
4. THE Goal_System SHALL prevent linking a wallet that is already linked to another active goal

### Requirement 5: Progress Visualization

**User Story:** As a user, I want to see a visual progress bar and milestone markers for my goals, so that I can quickly understand how close I am to achieving each goal.

#### Acceptance Criteria

1. THE Goal_System SHALL display a progress bar showing the ratio of current amount to target amount as a percentage between 0 and 100
2. THE Goal_System SHALL display milestone markers at 25%, 50%, 75%, and 100% on the progress bar
3. WHEN the goal progress crosses a milestone threshold, THE Goal_System SHALL animate the milestone marker using flutter_animate with a celebration effect
4. WHEN a goal reaches 100% completion, THE Goal_System SHALL display a Lottie celebration animation
5. THE Goal_System SHALL update the progress bar in real-time when deposits are added or wallet balance changes

### Requirement 6: Goal Editing and Deletion

**User Story:** As a user, I want to edit or delete my financial goals, so that I can adjust my savings plans as my financial situation changes.

#### Acceptance Criteria

1. WHEN the user edits a goal, THE Goal_System SHALL allow modification of name, target amount, deadline, icon, color, and linked wallet
2. IF the user reduces the target amount below the current saved amount, THEN THE Goal_System SHALL display a warning and cap the current amount at the new target
3. WHEN the user requests goal deletion, THE Goal_System SHALL display a confirmation dialog before proceeding
4. WHEN a goal is deleted, THE Goal_System SHALL remove the goal and all associated deposit records from the database
5. WHEN a goal with a linked wallet is deleted, THE Goal_System SHALL not affect the linked wallet balance

### Requirement 7: Gamification Integration

**User Story:** As a user, I want to earn badges and improve my health score when I reach savings milestones, so that I feel motivated to continue saving.

#### Acceptance Criteria

1. WHEN a goal reaches 25% completion, THE Gamification_System SHALL award the "quarter_saver" badge if not already unlocked
2. WHEN a goal reaches 50% completion, THE Gamification_System SHALL award the "half_way" badge if not already unlocked
3. WHEN a goal reaches 100% completion, THE Gamification_System SHALL award the "goal_achieved" badge if not already unlocked
4. WHEN the user completes 3 goals, THE Gamification_System SHALL award the "triple_saver" badge
5. WHEN the user completes 5 goals, THE Gamification_System SHALL award the "savings_master" badge
6. THE Gamification_System SHALL incorporate goal progress into the S_goal component of the health score calculation (maximum 5 points)
7. WHEN a goal has active progress (current amount greater than zero), THE Gamification_System SHALL contribute positively to the S_goal score proportional to the average completion percentage across all active goals

### Requirement 8: Notifications

**User Story:** As a user, I want to receive notifications when I reach milestones, when my deadline is approaching, and when I complete a goal, so that I stay informed and motivated.

#### Acceptance Criteria

1. WHEN a goal crosses a milestone threshold (25%, 50%, 75%), THE Notification_Service SHALL send a local notification congratulating the user
2. WHEN a goal reaches 100% completion, THE Notification_Service SHALL send a local notification celebrating the achievement
3. WHEN a goal deadline is 7 days away and the goal is less than 75% complete, THE Notification_Service SHALL send a reminder notification
4. WHEN a goal deadline is 1 day away and the goal is not complete, THE Notification_Service SHALL send an urgent reminder notification
5. THE Notification_Service SHALL not send duplicate notifications for the same milestone on the same goal

### Requirement 9: Data Persistence and Integrity

**User Story:** As a user, I want my goal data to be reliably stored locally, so that I do not lose my savings progress.

#### Acceptance Criteria

1. THE Goal_Repository SHALL store goals in a dedicated Drift database table with columns for id, userId, name, targetAmount, currentAmount, deadline, icon, color, linkedWalletId, trackingMode, status, and createdAt
2. THE Goal_Repository SHALL store deposit records in a separate Drift table with columns for id, goalId, amount, note, and createdAt
3. THE Goal_Repository SHALL enforce a foreign key constraint from deposits to goals with cascade delete
4. THE Goal_Repository SHALL enforce a foreign key constraint from goals to wallets (nullable) with set-null on delete
5. THE Goal_Repository SHALL provide Stream-based watch queries for real-time UI updates
6. THE Goal_Repository SHALL support filtering goals by status (active, completed, archived)

### Requirement 10: Goal Completion and Archival

**User Story:** As a user, I want completed goals to be archived so that I can see my achievement history without cluttering my active goals list.

#### Acceptance Criteria

1. WHEN a goal current amount reaches the target amount, THE Goal_System SHALL mark the goal status as completed
2. WHEN a goal is marked as completed, THE Goal_System SHALL record the completion date
3. THE Goal_System SHALL provide a separate view for completed and archived goals
4. WHEN the user manually archives an active goal, THE Goal_System SHALL change the goal status to archived and retain all data
5. IF a goal is already marked as completed, THEN a subsequent decrease in linked wallet balance SHALL NOT revert the goal status to active (completion is permanent)
6. IF a goal is already marked as completed and the linked wallet balance drops below the target amount, THEN THE Goal_System SHALL retain the completed status and display the original completion amount in the goal history

### Requirement 11: Correctness Properties

**User Story:** As a developer, I want property-based tests to verify the correctness of goal calculations and state transitions, so that the system behaves correctly for all valid inputs.

#### Acceptance Criteria

1. FOR ALL valid deposit amounts, depositing then querying the goal current amount SHALL produce a value equal to the sum of all deposits (round-trip invariant)
2. FOR ALL goals, the progress percentage SHALL equal the current amount divided by the target amount, clamped between 0.0 and 1.0 (metamorphic property)
3. FOR ALL sequences of deposits to a goal, the current amount SHALL remain less than or equal to the target amount (invariant property)
4. FOR ALL goals with a linked wallet, the goal current amount SHALL equal the linked wallet balance (model-based property)
5. FOR ALL valid goal creation inputs, creating a goal then reading the goal SHALL produce an equivalent goal object (round-trip property)
6. FOR ALL milestone calculations, applying the milestone check function multiple times SHALL produce the same set of unlocked milestones (idempotence property)
7. FOR ALL goal status transitions, a completed goal SHALL have current amount equal to target amount (invariant property)
