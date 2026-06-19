# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**For comprehensive architecture details, see:** `.kiro/steering/duasaku.md` (942 lines — full domain patterns, migration rules, security, animation guidelines)

---

## Project Overview

DuaSaku is a **100% offline-first** Flutter personal finance app with Clean Architecture, Riverpod 2.x state management, and Drift SQLite database. The app is bilingual (Indonesian/English) and features liquid-glass UI with gyroscope-driven parallax effects.

**Key Technologies:**
- Flutter SDK `^3.12.0`
- Riverpod `^2.5.1` (state management)
- Drift `^2.33.0` (SQLite ORM with reactive queries)
- GoRouter `^13.2.0` (navigation)
- TFLite + ML Kit (on-device transaction parsing)
- flutter_animate, Lottie (animations)
- easy_localization (i18n)

**Current Version:** 1.1.0+2

---

## Essential Commands

### Development Workflow
```bash
# Get dependencies
flutter pub get

# Generate Drift database code (REQUIRED after schema changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Run app (debug)
flutter run

# Run app (release — with optimizations)
flutter run --release

# Run tests
flutter test

# Run specific test file
flutter test test/path/to/test_file.dart

# Run tests with coverage
flutter test --coverage

# Lint (print() is ERROR-level in this project)
flutter analyze

# Format code
dart format lib/ test/

# Clean build artifacts
flutter clean

# Build APK (Android)
flutter build apk --release

# Build app bundle (Android — for Play Store)
flutter build appbundle --release
```

### Order Matters
1. Schema changes → `build_runner build` → restart app
2. Drift generates `.g.dart` files — **never edit manually**
3. After pulling updates: `flutter pub get` → `build_runner build` → restart

---

## Architecture Rules

### Feature Structure (MANDATORY)
Every feature MUST follow this structure:
```
lib/features/<feature>/
├── data/          # Repositories (Drift DB operations ONLY)
├── domain/        # Entities, repository interfaces, use cases (pure Dart)
├── presentation/  # Screens, widgets (UI only, no data imports)
├── providers/     # Riverpod providers (bridge presentation ↔ domain)
└── services/      # Feature-specific services (optional)
```

**Existing Features:**
- `auth` — Onboarding, PIN authentication
- `export_import` — Backup/restore with encryption
- `gamification` — Achievements, streaks, badges
- `geofencing` — Location-based spending alerts
- `goals` — Savings goals with milestones
- `insights` — Analytics, charts, spending patterns
- `profile` — User settings, preferences
- `recurring_transactions` — Scheduled transactions
- `smart_budget_alerts` — Budget threshold alerts
- `transactions` — Transaction CRUD, categories, budgets
- `wallets` — Multi-wallet management

### Core Structure
```
lib/core/
├── background/    # Workmanager background tasks
├── config/        # Environment config
├── constants/     # App-wide constants
├── local_db/      # Drift database, tables, DAOs
├── providers/     # Shared providers
├── routing/       # GoRouter configuration
├── security/      # PIN auth, NTP verification, encryption
├── theme/         # ThemeData, presets, Liquid Glass styles
├── utils/         # Helpers (amount extraction, fuzzy matching, etc.)
└── widgets/       # Shared reusable widgets
```

### Shared Services (lib/services/)
```
lib/services/
├── models/                              # Data models for services
│   ├── parsed_transaction.dart
│   ├── wallet_info.dart
│   └── category_info.dart
├── transaction_parser_service.dart      # Legacy wrapper (offline)
├── receipt_scanner_service.dart         # OCR for receipts
└── smart_input_ml_service.dart          # ML-based input assistance
```

### Dependency Direction (CRITICAL)
```
presentation → providers → domain ← data
                              ↑
                           services
```

**Rules:**
- Presentation NEVER imports `data/` directly (use `providers/`)
- Domain layer MUST be pure Dart (no Flutter/external packages)
- Services handle business logic/ML — repositories handle Drift DB ONLY
- All repository interfaces live in `domain/` — implementations in `data/`
- Feature-specific services go in `lib/features/<feature>/services/`
- Shared services (used by 2+ features) go in `lib/services/`

---

## Service vs Repository Boundary

| Layer | Handles | Does NOT Handle |
|-------|---------|-----------------|
| **Service** | External API calls, AI logic, transaction parsing, orchestration | Database queries |
| **Repository** | Drift CRUD, local DB queries, wallet balance adjustments | API calls, AI logic |

**CRITICAL:** Services MUST return **structured data types** (class/model), NOT raw `Map<String, dynamic>`.

```dart
// ✅ Correct — structured type
class GeminiService {
  Future<ParsedTransaction?> parseTransactionText({
    required String inputText,
    required List<WalletInfo> wallets,
  }) async {
    // Call API...
    return ParsedTransaction(amount: parsedAmount, category: parsedCategory);
  }
}

// ❌ Wrong — raw map
Future<Map<String, dynamic>> parseTransaction(String text) async {
  return jsonDecode(response.text); // Not type-safe!
}
```

---

## Riverpod 2.x Patterns

### Allowed Provider Types
```dart
// ✅ Complex sync state with mutations
NotifierProvider<WalletNotifier, WalletState>

// ✅ Complex async state (load + mutate)
AsyncNotifierProvider<TransactionNotifier, List<Transaction>>

// ✅ Read-only async data
FutureProvider.autoDispose<List<Transaction>>

// ✅ Realtime streams
StreamProvider.autoDispose<double>

// ✅ Simple primitives only
StateProvider<int>
```

### BANNED Providers (NEVER USE)
- ❌ `StateNotifierProvider` — deprecated in Riverpod 2.x (use `NotifierProvider`)
- ❌ `ChangeNotifierProvider` — incompatible with Riverpod immutability

### Migration Pattern: StateNotifier → Notifier
```dart
// ❌ OLD (deprecated)
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _repo;
  WalletNotifier(this._repo) : super(WalletState.initial());
}

// ✅ NEW (Riverpod 2.x)
class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    // ref available directly — no constructor injection
    return WalletState.initial();
  }
  
  Future<void> loadWallets() async {
    final repo = ref.read(walletRepositoryProvider);
    // ...
  }
}

final walletNotifierProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});
```

### Rules
- Use `ref.watch` in `build()`, `ref.read` in callbacks
- NEVER `ref.watch` inside `onPressed` or async functions
- Use `.autoDispose` for non-global providers
- Family providers for parameterized queries

---

## Drift Database Patterns

### Current Schema Version: 9
**CRITICAL:** Always check `AppDatabase.schemaVersion` in `lib/core/local_db/app_database.dart` before migrations.

### Tables Overview
```
Wallets                      # User wallets (Bank, E-Wallet, Cash)
Categories                   # Transaction categories (income/expense)
Transactions                 # All transactions with location data
Budgets                      # Monthly category budgets
RecurringTransactions        # Scheduled recurring transactions
RecurringExecutionLogs       # Execution history for recurring
Goals                        # Savings goals with tracking modes
GoalDeposits                 # Deposit history for goals
BudgetAlerts                 # Smart budget threshold alerts
BudgetAlertPreferences       # User alert settings
BudgetAlertThresholdStatus   # Threshold trigger tracking
```

### DAO Pattern (MANDATORY)
```dart
@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase> with _$TransactionDaoMixin {
  TransactionDao(super.db);

  // ✅ Use Stream for UI (auto-updates)
  Stream<List<Transaction>> watchRecent(int limit) {
    return (select(transactions)..limit(limit)).watch();
  }

  // ✅ Use Future for one-time reads
  Future<List<Transaction>> getByWallet(int walletId) {
    return (select(transactions)..where((t) => t.walletId.equals(walletId))).get();
  }
}
```

**Existing DAOs:**
- `RecurringTransactionDao` in `lib/features/recurring_transactions/data/`
- `GoalDao` in `lib/features/goals/data/`

### Schema Migrations (CRITICAL)
Every schema change MUST:
1. Increment `schemaVersion` in `AppDatabase`
2. Add migration step in `onUpgrade` with `if (from < N)` guard
3. **Never modify existing migration steps** (add new ones only)
4. Run `flutter pub run build_runner build --delete-conflicting-outputs`
5. Test migration path from previous version

```dart
@DriftDatabase(tables: [Transactions, Wallets])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 10; // Increment for every schema change

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(budgets);
      }
      if (from < 10) {
        await m.addColumn(transactions, transactions.newColumn);
      }
    },
  );
}
```

### Destructive Migrations (Drop Table/Column)
**MANDATORY backup before drop operations:**
```dart
if (from < 11) {
  // Step 1: Backup data to new structure
  final rows = await customSelect('SELECT * FROM old_table').get();
  for (final row in rows) {
    await into(newTable).insert(/* map columns */);
  }
  // Step 2: Drop ONLY after backup succeeds
  await m.deleteTable('old_table');
}
```

### Database Security
- **SQLCipher encryption** enabled by default
- Key stored in `flutter_secure_storage`
- Auto-migration from plaintext to encrypted on first launch
- UUID validation before SQL execution (SQL injection prevention)

---

## Code Standards

### Theming System (MANDATORY)
- ALWAYS use `Theme.of(context).colorScheme` for colors — NEVER hardcode
- Cards use **border** (NOT elevation/shadow)
- Border radius: **16px** for cards (NOT 8px)
- Transparent AppBar, no elevation
- Access liquid glass tokens: `Theme.of(context).extension<LiquidGlassTheme>()`

```dart
// ✅ Correct
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
    ),
  ),
)

// ❌ Wrong — hardcoded color
Container(color: Color(0xFF1A1A2E))
```

### Localization (MANDATORY)
ALL user-facing strings MUST use `.tr()` from easy_localization:
```dart
// ✅ Correct
Text('transaction.title'.tr())
Text('wallet.balance'.tr(args: [formattedAmount]))

// ❌ Wrong — hardcoded text
Text('Transaksi')
```

**Translation files:** `assets/translations/en.json`, `assets/translations/id.json`

### Naming Conventions
```dart
// Files: snake_case
transaction_repository.dart

// Classes: PascalCase
class TransactionRepository {}

// Variables/functions: camelCase
final totalBalance = ref.watch(balanceProvider);

// Constants: camelCase (NOT SCREAMING_CASE)
const defaultWalletName = 'Utama';

// Providers: camelCase + Provider suffix
final transactionListProvider = ...

// Private members: _camelCase
String _internalHelper() => '';
```

### Widget Structure
- Prefer `const` constructors
- Extract widgets to separate file if > 80 lines
- Use `ConsumerWidget` (NOT Consumer wrapper)
- DON'T nest more than 5 levels deep
- Use `SingleChildScrollView` with physics for scrollable content

### Animation Guidelines
- Duration: **200-400ms** for transitions
- Default curve: `Curves.easeOutCubic`
- Max 5-8 stagger items in lists
- Use Shimmer for loading (NOT generic CircularProgressIndicator)
- Liquid glass tokens: `LiquidGlassTheme.of(context).animationDuration`

### Code Quality Rules (from analysis_options.yaml)
- **`avoid_print: error`** — NO `print()` statements (use proper logging)
- `prefer_const_constructors: true` — Use const where possible
- `prefer_const_declarations: true`
- `always_declare_return_types: true`
- `prefer_final_locals: true`

---

## Offline-First Status

**100% offline-first.** No external API calls for core functionality.

### Transaction Parsing
- Uses `LocalTransactionParserService` (regex + fuzzy matching)
- Regex-based amount extraction with support for shorthand (k, jt, rb)
- Fuzzy Levenshtein distance matching for categories/wallets
- Intent classification via keyword patterns
- Legacy `TransactionParserService` wraps offline parser for compatibility

### ML Features (On-Device)
- **TFLite models** for transaction classification (stored in `assets/ml/`)
- **ML Kit** for text recognition (OCR from receipts)
- All processing happens locally — no data leaves device

### Data Storage
- **Drift SQLite** with SQLCipher encryption
- All user data stays on device
- Export/import with AES encryption for backups

---

## Android Build Configuration

**Current Settings (android/app/build.gradle.kts):**
- `minSdk: 26` (Android 8.0 Oreo)
- `targetSdk: 35` (Android 15)
- `compileSdk: 36`
- Java/Kotlin: **JVM 17**
- NDK version: Managed by Flutter
- Core library desugaring enabled (for newer Java APIs on older Android)
- TFLite model compression: `noCompress("tflite", "lite")`

### ProGuard
Release builds use ProGuard optimization. Rules in `android/app/proguard-rules.pro`.

---

## Navigation & Routing

### GoRouter Structure
- **Protected routes** require PIN/biometric auth
- **StatefulShellRoute** for bottom nav persistence
- Main tabs: `/home`, `/history`, `/insights`, `/profile`
- Deep link scheme: `duasaku://`

### Route Examples
```dart
context.go('/home');                          // Navigate to home
context.push('/wallets/detail?id=abc');       // Push wallet detail
context.go('/pin-auth?mode=change');          // Change PIN mode
```

### Deep Links
- `duasaku://new_transaction` — Quick transaction entry
- Use `snake_case` for paths (e.g., `duasaku://wallet_detail?id=123`)

---

## Background Tasks

### Workmanager Integration
Background tasks configured in `lib/core/background/`:
- `recurring_executor.dart` — Executes scheduled recurring transactions
- `background_task_helper.dart` — Task registration and scheduling

### Task Constraints
- Battery not low
- Device not in doze mode
- Execution window: configurable per task

---

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/transactions/data/transaction_repository_test.dart

# Run tests with coverage
flutter test --coverage

# View coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
```

### Test Structure
- **Unit tests** for domain logic, repositories, services
- **Widget tests** for presentation components
- **Integration tests** for critical flows
- **Property-based tests** using `glados` package (see `test/features/smart_budget_alerts/`)

### Mocking
- Use `mockito` for repository/service mocks
- Generate mocks: `flutter pub run build_runner build`

---

## Performance Best Practices

### Widget Optimization
- Use `const` constructors to avoid rebuilds
- `ListView.builder` for long lists (NOT `ListView`)
- `.autoDispose` on providers for memory management
- Use `select` to avoid unnecessary rebuilds:
  ```dart
  final balance = ref.watch(walletProvider.select((w) => w.balance));
  ```

### Database Optimization
- Use indexed columns for frequent queries (see `@TableIndex` in `app_database.dart`)
- Batch inserts when adding multiple records
- Use `watch()` for reactive UI, `get()` for one-time reads
- Enable WAL mode (already enabled: `PRAGMA journal_mode = WAL`)

---

## Common Gotchas

### Build Runner
- Always run after schema changes: `flutter pub run build_runner build --delete-conflicting-outputs`
- Generated files (`.g.dart`) must not be edited manually
- If stuck: `flutter clean` → `flutter pub get` → rebuild

### Riverpod 2.x
- Use `NotifierProvider` (NOT deprecated `StateNotifierProvider`)
- `ref.watch` in `build()`, `ref.read` in callbacks
- NEVER `ref.watch` inside `onPressed` or async functions

### Drift Migrations
- Never modify existing migration steps — add new ones only
- Test migration path from previous schema version
- Backup data before destructive operations (drop table/column)

### Localization
- After modifying translation JSON files, hot restart required (hot reload insufficient)
- Missing keys fall back to key name (e.g., `'missing.key'.tr()` → "missing.key")

### Print Statements
- `print()` is **ERROR-level** in this project (see `analysis_options.yaml`)
- Use proper logging or remove debug prints before commit
