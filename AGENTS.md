# DuaSaku — Agent Instruction File

Flutter finance app with Clean Architecture, Riverpod 2.x, Drift database, and local-first design.

**For comprehensive details, see:** `.kiro/steering/duasaku.md` (942 lines — full domain patterns, migration rules, security, animation guidelines)

---

## Commands

### Core Workflow
```bash
# Get dependencies
flutter pub get

# Generate Drift DB code (REQUIRED after schema changes)
flutter pub run build_runner build --delete-conflicting-outputs

# Run app
flutter run

# Run tests
flutter test

# Lint (print() is ERROR-level)
flutter analyze
```

### Order Matters
1. Schema changes → `build_runner build` → restart app
2. Drift generates `.g.dart` files — never edit manually

---

## Architecture

### Feature Structure (MANDATORY)
```
lib/features/<feature>/
├── data/          # Repositories (Drift DB ops ONLY)
├── domain/        # Entities, repository interfaces, use cases
├── presentation/  # Screens, widgets (UI only)
├── providers/     # Riverpod providers
└── services/      # External API calls, non-DB logic
```

### Dependency Rules
- **Presentation** → never imports `data/` directly (use `providers/`)
- **Domain** → pure Dart, no Flutter/external packages
- **Repositories** → Drift DB operations ONLY
- **Services** → API calls, AI, parsing (NOT DB queries)

### Service vs Repository
| Layer | Handles | Does NOT Handle |
|-------|---------|-----------------|
| **Service** | External APIs, Gemini AI, parsing, orchestration | Database queries |
| **Repository** | Drift CRUD, local DB queries | API calls |

**CRITICAL:** Services WAJIB return **structured data types** (class/model), BUKAN raw `Map<String, dynamic>` atau JSON maps.

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

## Riverpod Patterns

### Provider Types (Use Correct One)
```dart
// ✅ Sync state with mutations
NotifierProvider<WalletNotifier, WalletState>

// ✅ Async state with mutations (load + mutate)
AsyncNotifierProvider<TransactionNotifier, List<Transaction>>

// ✅ Read-only async data
FutureProvider.autoDispose<List<Transaction>>

// ✅ Realtime streams
StreamProvider.autoDispose<double>

// ✅ Simple primitives only
StateProvider<int>
```

### BANNED Providers
- ❌ `StateNotifierProvider` — deprecated in Riverpod 2.x (use `NotifierProvider`)
- ❌ `ChangeNotifierProvider` — incompatible with Riverpod immutability

### Migration Pattern (StateNotifier → Notifier)
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
- Never `ref.watch` inside `onPressed` or async functions
- Use `.autoDispose` for non-global providers
- Family providers for parameterized queries

---

## Drift Database

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

### Schema Migrations
- Increment `schemaVersion` for every schema change
- Add migration step in `onUpgrade` with `if (from < N)` guard
- Never modify existing migration steps (add new ones only)
- Test migrations from old version to new

#### Destructive Migrations (Drop Table/Column)
**WAJIB backup data before drop operations:**
```dart
if (from < 6) {
  // Backup data ke struktur baru
  final rows = await customSelect('SELECT * FROM old_table').get();
  for (final row in rows) {
    await into(newTable).insert(/* map columns */);
  }
  // Drop HANYA setelah backup berhasil
  await m.deleteTable('old_table');
}
```
Rules:
- Data loss tidak bisa di-undo — backup WAJIB
- Jika migration gagal, app harus bisa retry tanpa corrupt data
- JANGAN drop table dengan active foreign key references
- Rename column: buat baru → copy data → drop lama (SQLite limitation)

### After Schema Changes
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Domain Layer Interfaces

### Abstract Repository Pattern (MANDATORY)
```dart
// domain/wallet_repository_interface.dart
abstract class WalletRepositoryInterface {
  Future<List<WalletModel>> getWallets(String userId);
  Future<void> createWallet(WalletModel wallet);
}

// data/wallet_repository.dart
class WalletRepository implements WalletRepositoryInterface {
  final AppDatabase _db;
  WalletRepository(this._db);

  @override
  Future<List<WalletModel>> getWallets(String userId) {
    return _db.walletDao.getByUser(userId);
  }
}

// Provider MUST use abstract interface type
final walletRepositoryProvider = Provider<WalletRepositoryInterface>((ref) {
  final db = ref.watch(databaseProvider);
  return WalletRepository(db); // concrete impl, abstract type
});
```

### Rules
- ALL repositories MUST implement abstract interface from `domain/`
- Interfaces use domain models, NOT database-specific types
- Provider type = abstract interface, NOT concrete class
- Mock interfaces in tests, not concrete repositories

---

## Error Handling

### Result Pattern (MANDATORY for expected failures)
```dart
sealed class Result<T, E> {
  const Result();
}

final class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}

// Usage
Future<Result<TransactionModel, AppError>> getById(int id) async {
  try {
    final result = await _dao.findById(id);
    if (result == null) {
      return Failure(AppError.notFound('Transaction $id not found'));
    }
    return Success(result);
  } on SqliteException catch (e) {
    return Failure(AppError.database(e.message));
  } catch (e) {
    rethrow; // Unexpected system error
  }
}

// In provider
final result = await ref.read(transactionRepositoryProvider).getById(id);
switch (result) {
  case Success(:final value):
    state = AsyncData(value);
  case Failure(:final error):
    state = AsyncError(error, StackTrace.current);
}
```

### When to Throw vs Return Failure
| Situation | Action |
|-----------|--------|
| Not found, validation error, network timeout, DB constraint | `return Failure(...)` |
| Out of memory, corrupted DB, null assertion | `rethrow` (bug) |

---

## Theming

### Rules
- Always use `Theme.of(context).colorScheme` (never hardcode colors)
- Cards use borders, NOT elevation/shadows
- Border radius: 16px for cards
- AppBar: transparent, no elevation

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

// ❌ Wrong
Container(color: Color(0xFF1A1A2E)) // Hardcoded
Card(elevation: 4) // Use borders instead
borderRadius: BorderRadius.circular(8) // Should be 16
```

---

## Animation

### Rules
- Duration standar: **200-400ms** untuk UI transitions
- Default curve: `Curves.easeOutCubic`
- Max stagger items: 5-8 (jangan animate terlalu banyak sekaligus)
- Loading states: gunakan **Shimmer**, bukan CircularProgressIndicator generik
- Lottie untuk animasi kompleks (empty states, celebrations, onboarding)
- `flutter_animate` untuk micro-interactions dan list animations

### flutter_animate Pattern
```dart
ListView.builder(
  itemBuilder: (context, index) {
    return item
      .animate()
      .fadeIn(delay: Duration(milliseconds: index * 50))
      .slideY(begin: 0.1, end: 0);
  },
)
```

---

## Security

### Anti-Tampering
- App verifikasi waktu via NTP sebelum operasi sensitif
- Jika waktu device tidak sinkron → app terkunci
- PIN/biometric auth required saat app resume dari background

### Secure Storage Rules
```dart
// Untuk data sensitif (tokens, keys)
final storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);

// Untuk preferences biasa (theme, locale)
final prefs = SharedPreferences.getInstance();
await prefs.setString('key', value);
```

### Rules
- JANGAN simpan financial data di SharedPreferences — gunakan Drift (encrypted)
- JANGAN log sensitive data (amounts, account numbers) di debug mode
- Selalu validate input amounts (no negative, max limit)

---

## Financial UX Patterns

### Transaction Entry
- Quick entry dari home widget (deep link: `duasaku://new_transaction`)
- Auto-parse dari notifikasi bank
- Haptic feedback pada submit transaksi

### Data Display
- Format currency: `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ')`
- Gunakan `fl_chart` untuk visualisasi — BUKAN text-only summaries
- Warna: hijau untuk income, merah untuk expense (universal convention)
- Tampilkan perubahan dengan animasi (angka counting up/down)

### Empty States
- Setiap list HARUS punya empty state yang informatif
- Sertakan CTA (call-to-action) di empty state
- Gunakan Lottie animation untuk empty states

---

## Localization

### Rules
- ALL user-facing strings MUST use `.tr()` from easy_localization
- Files: `assets/translations/{locale}.json`
- Never hardcode Indonesian or English strings

```dart
// ✅ Correct
Text('transaction.title'.tr())
Text('wallet.balance'.tr(args: [formattedAmount]))

// ❌ Wrong
Text('Transaksi')
Text('Saldo: Rp 100.000')
```

---

## Code Style

### Naming
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
```

### Widget Rules
- Prefer `const` constructors
- Extract widgets to separate file if > 80 lines
- Use `ConsumerWidget` / `ConsumerStatefulWidget` (not Consumer wrapper)
- Never nest > 5 levels (extract to method/widget)
- Always add `const` to immutable widgets

---

## Quirks & Gotchas

### print() is ERROR
`analysis_options.yaml` treats `avoid_print` as error. Use `debugPrint()` instead.

### Drift Code Generation
- After changing tables/DAOs, run `build_runner build`
- Generated files (`.g.dart`) are committed to repo
- Never edit `.g.dart` manually

### Deep Links
- Scheme: `duasaku://`
- Naming: `snake_case` (e.g., `duasaku://new_transaction`)
- Handler: `_handleWidgetClick` in `main.dart`

#### Registered Routes
| Route | Purpose | Parameters |
|-------|---------|------------|
| `duasaku://new_transaction` | Opens transaction entry bottom sheet | None |
| `duasaku://wallet_detail` | Opens wallet detail screen | `?id=<wallet_id>` |

### Background Tasks
- Use `workmanager` package
- Min frequency: 15 minutes (Android WorkManager limit)
- Always add constraints: `networkType`, `requiresBatteryNotLow`
- Return `true` = success, `false` = retry with backoff
- Never throw exceptions (catch and return `false`)

#### Constraints (MANDATORY)
| Constraint | When to Use |
|-----------|-------------|
| `networkType: NetworkType.connected` | WAJIB for all sync tasks |
| `requiresBatteryNotLow: true` | WAJIB for periodic tasks |
| `requiresCharging: true` | Optional — for heavy operations |

#### Retry & Failure Handling
```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final success = await _performSync();
      return Future.value(success); // true = done, false = retry
    } catch (e) {
      debugPrint('[BackgroundSync] Failed: $e');
      return Future.value(false); // Triggers exponential backoff retry
    }
  });
}
```

---

## Performance

- Use `const` widgets to avoid rebuilds
- `ListView.builder` (not `ListView`) for long lists
- `.autoDispose` providers for memory management
- Use `select` to avoid full rebuilds:
  ```dart
  final balance = ref.watch(walletProvider.select((w) => w.balance));
  ```

---

## Planning Protocol

### For New Features or Major Refactors
Create `docs/specs/<feature-slug>/` with:
1. `requirements.md` — functional requirements, acceptance criteria
2. `design.md` — architecture, data flow, Riverpod/Drift integration
3. `tasks.md` — task breakdown, agent assignments, dependency graph

---

## Testing

```bash
flutter test
```

- Unit tests for domain logic
- Widget tests for presentation
- Integration tests for critical flows
- Use `mockito` for mocking
- Test file naming: `<feature>_test.dart`

---

## AG Kit Workflows (Slash Commands)

This repository is equipped with **AG Kit**, a modular AI agent capability expansion toolkit located in the `.agent/` directory. If you are an AI assistant, you can utilize the following workflows and slash commands:

- `/plan` — Create a project plan using the `project-planner` agent (saves to `implementation_plan.md`).
- `/verify` — Prove code changes work by running validation commands.
- `/create` — Scaffolds new components or directories using the `app-builder` skill.
- `/debug` — Activates DEBUG mode for systematic problem investigation.
- `/status` — Displays the current status of all agents and the active task checklist (`task.md`).
- `/enhance` — Add or update features in existing parts of the application.
- `/orchestrate` — Coordinate multiple agents for complex tasks.
- `/remember` — Persists important information to the persistent memory system (`.agent/memory/`).

Always check if a workflow is relevant to the user request. Refer to `.agent/rules/GEMINI.md` for the universal AI guidelines and the Socratic Gate protocol.

---

## Master Validation & Verification Scripts

Before completing any task, you **MUST** run the validation scripts provided in the `.agent` kit. A task is not complete unless all required checks pass.

1. **Pre-commit / Development Check (Core Validation)**:
   ```bash
   python .agent/scripts/checklist.py .
   ```
   This automatically checks:
   - Security (vulnerabilities, secrets)
   - Code quality (lint, type coverage)
   - Database schema consistency
   - Unit/Widget test suites

2. **Pre-deployment Check (Full Verification Suite)**:
   ```bash
   python .agent/scripts/verify_all.py . --url <URL>
   ```

---

## Rule Hierarchy

For AI agents working in this workspace, rules are enforced in the following order:
1. **P0 (GEMINI.md)**: Universal guidelines, agent routing, Socratic Gate (`.agent/rules/GEMINI.md`).
2. **P1 (Project Steering & Agent MD)**:
   - This file (`AGENTS.md`) - Core guidelines summary.
   - **Full Steering Rules**: [.kiro/steering/duasaku.md](file:///c:/Codingg/duasaku_app/.kiro/steering/duasaku.md) - Deep domain specific patterns (Riverpod, Drift, local-first architecture, error handling).
   - Specialist agent definitions inside `.agent/agents/` (e.g., `mobile-developer.md`).
3. **P2 (Skills)**: Domain-specific skill files in `.agent/skills/` (e.g., `clean-code`, `mobile-design`, `design-audit`).

---

## Verification Checklist (Before "Done")

- [ ] `python .agent/scripts/checklist.py .` passes successfully (no critical errors)
- [ ] `flutter analyze` passes (no errors)
- [ ] `build_runner build` if schema changed
- [ ] No `print()` statements (use `debugPrint`)
- [ ] No hardcoded colors (use `Theme.of(context)`)
- [ ] All strings use `.tr()` localization
- [ ] Repositories implement abstract interfaces
- [ ] No `StateNotifierProvider` or `ChangeNotifierProvider`
- [ ] Services return structured types (not raw `Map`)
- [ ] Tests pass for critical paths

---

**Full steering rules:** `.kiro/steering/duasaku.md` (942 lines — read for domain patterns, Result usage, migration rules, security, animation guidelines)

