---
inclusion: auto
description: Flutter finance app (DuaSaku) development guide — architecture rules, Riverpod patterns, Drift database, theming, and coding standards.
---

# DuaSaku — Flutter Finance App Development Guide

Steering khusus untuk proyek DuaSaku: aplikasi manajemen keuangan pribadi berbasis Flutter dengan arsitektur clean, Riverpod state management, dan Drift local database.

## Specification & Planning Protocol (WAJIB)

Setiap kali mengimplementasikan fitur baru, perubahan struktural, atau melakukan refactoring besar, Anda **HARUS** merencanakan langkah-langkah kerja terlebih dahulu dengan membuat folder baru di bawah `docs/specs/<feature-slug>/` yang berisi 3 berkas utama berikut sebelum mulai menulis kode implementasi:
1. **`requirements.md`** — Dokumen persyaratan fungsional, batasan teknis, dan kriteria penerimaan (*acceptance criteria*) dari fitur.
2. **`design.md`** — Penjelasan detail arsitektur komponen, desain sistem, *flow pipeline* data, struktur kelas, dan rencana integrasi state management (Riverpod/Drift).
3. **`tasks.md`** — Daftar checklist pengerjaan (*task breakdown*) dengan penentuan penanggung jawab (agent), skill terkait, kriteria verifikasi, serta grafik urutan/dependensi tugas (*dependency waves*).

## Project Identity

- **Nama:** DuaSaku (Dua Saku = Two Pockets)
- **Platform:** Flutter (Dart SDK ^3.12.0)
- **Bahasa UI:** Bilingual (Indonesia + English via easy_localization)
- **Target:** Android & iOS
- **Arsitektur:** Feature-based Clean Architecture

## Tech Stack

| Layer | Technology |
|-------|-----------|
| State Management | flutter_riverpod ^2.5.1 |
| Routing | go_router ^13.2.0 |
| Local DB | Drift ^2.33.0 (SQLite) |
| Auth | local_auth (PIN/biometric), flutter_secure_storage |
| AI | google_generative_ai (Gemini) |
| Charts | fl_chart ^0.68.0 |
| Animations | flutter_animate + lottie |
| Background | workmanager |
| Location | geolocator |
| Notifications | flutter_local_notifications |
| Security | NTP time verification, crypto, flutter_secure_storage |
| Widget | home_widget (home screen widget) |

## Architecture Rules

### Feature Structure (WAJIB)
Setiap feature HARUS mengikuti struktur ini:
```
lib/features/<feature_name>/
├── data/          # Repository implementations, data sources, models
├── domain/        # Entities, repository interfaces, use cases
├── presentation/  # Screens, widgets (UI only)
├── providers/     # Riverpod providers
└── services/      # Feature-specific services
```

### Core Structure
```
lib/core/
├── background/    # Background task helpers
├── config/        # Environment config (.env)
├── local_db/      # Drift database, tables, DAOs
├── providers/     # Shared providers
├── routing/       # GoRouter configuration
├── security/      # PIN auth, NTP verification, anti-tampering
├── theme/         # ThemeData, presets, ThemeNotifier
└── widgets/       # Shared reusable widgets
```

### Dependency Direction
```
presentation → providers → domain ← data
                              ↑
                           services
```
- Presentation TIDAK BOLEH import data layer langsung
- Domain layer TIDAK BOLEH depend on Flutter/external packages
- Providers menjembatani presentation dan domain

## Service Layer

### Overview
Service Layer bertanggung jawab untuk **external API calls** dan **logic yang bukan database operations**. Repositories hanya menangani local database (Drift) operations secara eksklusif.

### Structure
```
lib/services/                          # Shared services (digunakan lintas feature)
├── gemini_service.dart
├── transaction_parser_service.dart
└── models/
    ├── parsed_transaction.dart
    └── wallet_info.dart

lib/features/<feature>/services/       # Feature-specific services
└── <feature>_service.dart
```

- **`lib/services/`** — Shared services yang digunakan oleh lebih dari satu feature (contoh: `GeminiService`, `TransactionParserService`)
- **`lib/features/<feature>/services/`** — Services yang hanya relevan untuk satu feature tertentu

### Responsibilities

| Layer | Responsibility |
|-------|---------------|
| **Service Layer** | External API calls (Gemini AI, HTTP endpoints), AI logic, parsing, orchestration antar external systems |
| **Repository (Data Layer)** | Local database CRUD operations (Drift), wallet balance adjustments, data persistence |

### Rules
- Services menangani **semua** external API calls (Gemini AI, REST endpoints, third-party SDKs)
- Repositories menangani **hanya** local database operations (Drift queries, inserts, updates, deletes)
- JANGAN taruh API calls di repository — gunakan service
- JANGAN taruh database queries di service — gunakan repository
- Services WAJIB return **structured data types** (class/model), BUKAN raw `Map<String, dynamic>` atau JSON maps

### Contoh yang BENAR:
```dart
// ✅ Service returns structured type
class GeminiService {
  Future<ParsedTransaction?> parseTransactionText({
    required String inputText,
    required List<WalletInfo> wallets,
    required List<CategoryInfo> categories,
  }) async {
    // Call Gemini API...
    return ParsedTransaction(
      amount: parsedAmount,
      category: parsedCategory,
      type: parsedType,
      notes: inputText,
    );
  }
}
```

### Contoh yang SALAH:
```dart
// ❌ Service returning raw JSON map
Future<Map<String, dynamic>> parseTransaction(String text) async {
  final response = await geminiApi.generate(text);
  return jsonDecode(response.text); // Raw map — tidak type-safe!
}

// ❌ Repository melakukan API call
class TransactionRepository {
  Future<ParsedTransaction> parseWithAI(String text) async {
    final model = GenerativeModel(...); // API call di repository!
    // ...
  }
}
```

### Provider Wiring
```dart
final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService(apiKey: ref.watch(geminiApiKeyProvider));
});

final transactionParserProvider = Provider<TransactionParserService>((ref) {
  return TransactionParserService(ref.watch(geminiServiceProvider));
});
```

## Domain Layer Interfaces

### Rule: Abstract Repository Interfaces (WAJIB)

Setiap repository HARUS memiliki abstract class interface di `lib/features/<feature>/domain/`. Concrete implementations di `data/` layer HARUS implement interface tersebut. Ini memastikan dependency inversion dan testability (mock-friendly).

### Contoh: Abstract Interface + Concrete Implementation

**Abstract interface** (`lib/features/wallets/domain/wallet_repository_interface.dart`):
```dart
abstract class WalletRepositoryInterface {
  Future<List<WalletModel>> getWallets(String userId);
  Stream<List<WalletModel>> watchWallets(String userId);
  Future<void> createWallet(WalletModel wallet);
  Future<void> updateWallet(WalletModel wallet);
  Future<void> deleteWallet(String walletId);
}
```

**Concrete implementation** (`lib/features/wallets/data/wallet_repository.dart`):
```dart
class WalletRepository implements WalletRepositoryInterface {
  final AppDatabase _db;

  WalletRepository(this._db);

  @override
  Future<List<WalletModel>> getWallets(String userId) {
    return _db.walletDao.getByUser(userId);
  }

  @override
  Stream<List<WalletModel>> watchWallets(String userId) {
    return _db.walletDao.watchByUser(userId);
  }

  @override
  Future<void> createWallet(WalletModel wallet) {
    return _db.walletDao.insertWallet(wallet);
  }

  @override
  Future<void> updateWallet(WalletModel wallet) {
    return _db.walletDao.updateWallet(wallet);
  }

  @override
  Future<void> deleteWallet(String walletId) {
    return _db.walletDao.deleteWallet(walletId);
  }
}
```

### Provider Dependency Rule

Providers HARUS depend on abstract interfaces, BUKAN concrete implementations. Ini memungkinkan swapping implementasi (testing, different backends) tanpa mengubah provider consumers.

```dart
// ✅ Benar — provider type adalah abstract interface
final walletRepositoryProvider = Provider<WalletRepositoryInterface>((ref) {
  final db = ref.watch(databaseProvider);
  return WalletRepository(db); // concrete, tapi type-nya abstract
});

// ❌ Salah — provider type adalah concrete class
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return WalletRepository(db);
});
```

### Rules
- SEMUA repository di `lib/features/<feature>/data/` HARUS implement abstract interface dari `domain/`
- Abstract interface TIDAK BOLEH import package external (Drift, HTTP, dll) — pure Dart only
- Method signatures di interface menggunakan domain models, bukan database-specific types
- Saat menulis tests, mock abstract interface — bukan concrete repository

## Riverpod Patterns

### Provider Types (gunakan yang tepat)
```dart
// Untuk state sederhana yang bisa berubah
final counterProvider = StateProvider<int>((ref) => 0);

// Untuk complex synchronous state dengan logic (Riverpod 2.x Notifier)
final walletNotifierProvider = NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});

class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    final repo = ref.watch(walletRepositoryProvider);
    return WalletState.initial(repo);
  }

  void addWallet(Wallet wallet) {
    state = state.copyWith(wallets: [...state.wallets, wallet]);
  }
}

// Untuk complex async state (API calls, DB queries with mutations)
final transactionNotifierProvider =
    AsyncNotifierProvider<TransactionNotifier, List<Transaction>>(() {
  return TransactionNotifier();
});

class TransactionNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    final repo = ref.watch(transactionRepositoryProvider);
    return repo.getAll();
  }

  Future<void> addTransaction(Transaction tx) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.insert(tx);
      return repo.getAll();
    });
  }
}

// Untuk async data read-only (tanpa mutations)
final transactionsProvider = FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getAll();
});

// Untuk stream data (realtime updates)
final balanceStreamProvider = StreamProvider.autoDispose<double>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchTotalBalance();
});
```

### ⛔ Banned Providers (JANGAN GUNAKAN)

| Provider | Status | Alasan |
|----------|--------|--------|
| `StateNotifierProvider` | ❌ BANNED | Deprecated di Riverpod 2.x. Gunakan `NotifierProvider` atau `AsyncNotifierProvider` sebagai pengganti. `Notifier` memiliki akses langsung ke `ref` tanpa perlu constructor injection. |
| `ChangeNotifierProvider` | ❌ BANNED | Mutable state pattern dari `package:provider`. Tidak kompatibel dengan Riverpod's immutable state philosophy. Menyebabkan unpredictable rebuilds dan sulit di-test. |

### Migration: StateNotifier → Notifier (Before/After)

**BEFORE (deprecated — jangan gunakan lagi):**
```dart
// ❌ OLD: StateNotifier pattern
class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepositoryInterface _repo;

  WalletNotifier(this._repo) : super(WalletState.initial());

  Future<void> loadWallets() async {
    state = state.copyWith(isLoading: true);
    final wallets = await _repo.getWallets();
    state = state.copyWith(wallets: wallets, isLoading: false);
  }
}

final walletNotifierProvider =
    StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(walletRepositoryProvider));
});
```

**AFTER (modern — gunakan ini):**
```dart
// ✅ NEW: Notifier pattern (Riverpod 2.x)
class WalletNotifier extends Notifier<WalletState> {
  @override
  WalletState build() {
    // ref tersedia langsung — tidak perlu constructor injection
    return WalletState.initial();
  }

  Future<void> loadWallets() async {
    state = state.copyWith(isLoading: true);
    final repo = ref.read(walletRepositoryProvider);
    final wallets = await repo.getWallets();
    state = state.copyWith(wallets: wallets, isLoading: false);
  }
}

final walletNotifierProvider =
    NotifierProvider<WalletNotifier, WalletState>(() {
  return WalletNotifier();
});
```

**Key differences:**
- `Notifier` memiliki `ref` sebagai property — tidak perlu inject via constructor
- `build()` method menggantikan constructor `super(initialState)`
- Provider factory hanya return instance baru: `() => WalletNotifier()`
- Untuk async state, gunakan `AsyncNotifier` + `AsyncNotifierProvider`

**AsyncNotifier migration (untuk state yang di-load async):**
```dart
// ✅ AsyncNotifier — state otomatis loading/error/data
class TransactionListNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    final repo = ref.watch(transactionRepositoryProvider);
    return repo.fetchAll();
  }

  Future<void> deleteTransaction(int id) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.delete(id);
    ref.invalidateSelf(); // Trigger rebuild
  }
}

final transactionListProvider =
    AsyncNotifierProvider<TransactionListNotifier, List<Transaction>>(() {
  return TransactionListNotifier();
});
```

### Rules
- Gunakan `.autoDispose` untuk providers yang tidak perlu hidup selamanya
- Gunakan `ref.watch` di build method, `ref.read` di callbacks/event handlers
- JANGAN gunakan `ref.watch` di dalam `onPressed`, `onTap`, atau async functions
- Family providers untuk parameterized queries:
```dart
final walletByIdProvider = FutureProvider.autoDispose.family<Wallet?, int>((ref, id) {
  return ref.watch(walletRepositoryProvider).getById(id);
});
```
- Gunakan `NotifierProvider` untuk complex synchronous state dengan mutations
- Gunakan `AsyncNotifierProvider` untuk complex async state (load + mutate)
- Gunakan `FutureProvider` untuk read-only async data tanpa mutations
- Gunakan `StreamProvider` untuk realtime data streams
- Gunakan `StateProvider` hanya untuk state primitif sederhana (counter, toggle, selected index)

## Drift Database Patterns

### Table Definition
```dart
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  IntColumn get walletId => integer().references(Wallets, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get categoryType => intEnum<CategoryType>()();
}
```

### DAO Pattern
```dart
@DriftAccessor(tables: [Transactions])
class TransactionDao extends DatabaseAccessor<AppDatabase> with _$TransactionDaoMixin {
  TransactionDao(super.db);

  Future<List<Transaction>> getByWallet(int walletId) {
    return (select(transactions)..where((t) => t.walletId.equals(walletId))).get();
  }

  Stream<List<Transaction>> watchRecent(int limit) {
    return (select(transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit))
    .watch();
  }
}
```

### Rules
- Selalu gunakan `Stream` (watch) untuk data yang ditampilkan di UI — otomatis update
- Gunakan `Future` (get) untuk one-time reads
- Jalankan `dart run build_runner build` setelah mengubah table/DAO definitions
- JANGAN edit file `.g.dart` secara manual

## Error Handling

### Result Pattern (WAJIB untuk expected failures)

Gunakan sealed class `Result<T, E>` untuk mengembalikan success atau failure secara type-safe, tanpa melempar exception untuk kegagalan yang bisa diprediksi.

#### Result Sealed Class Definition

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
```

#### Usage Rules

- **Service dan repository methods** HARUS return `Result<T, E>` untuk operasi yang bisa gagal secara expected (not found, validation error, network timeout, constraint violation).
- **JANGAN throw exception** untuk expected failures — gunakan `Failure(error)` sebagai return value.
- **Unexpected system errors** (out of memory, corrupted database, unrecoverable state) BOLEH di-rethrow sebagai unrecoverable exception — ini menandakan bug atau kondisi fatal yang tidak bisa di-handle oleh caller.

#### Contoh Penggunaan di Repository

```dart
abstract class TransactionRepositoryInterface {
  Future<Result<TransactionModel, AppError>> getById(int id);
  Future<Result<void, AppError>> insertTransaction(TransactionModel tx);
}

class TransactionRepository implements TransactionRepositoryInterface {
  @override
  Future<Result<TransactionModel, AppError>> getById(int id) async {
    try {
      final result = await _dao.findById(id);
      if (result == null) {
        return Failure(AppError.notFound('Transaction $id not found'));
      }
      return Success(result);
    } on SqliteException catch (e) {
      // Expected DB constraint error
      return Failure(AppError.database(e.message));
    } catch (e) {
      // Unexpected system error — rethrow as unrecoverable
      rethrow;
    }
  }
}
```

#### Contoh Penggunaan di Provider/Notifier

```dart
final result = await ref.read(transactionRepositoryProvider).getById(id);
switch (result) {
  case Success(:final value):
    state = AsyncData(value);
  case Failure(:final error):
    state = AsyncError(error, StackTrace.current);
}
```

#### Kapan Throw vs Return Failure

| Situasi | Pendekatan |
|---------|-----------|
| Data not found | `return Failure(AppError.notFound(...))` |
| Validation gagal | `return Failure(AppError.validation(...))` |
| Network timeout | `return Failure(AppError.network(...))` |
| DB constraint violation | `return Failure(AppError.database(...))` |
| Out of memory | `rethrow` (unrecoverable) |
| Corrupted database file | `rethrow` (unrecoverable) |
| Null assertion failed | `rethrow` (bug — harus diperbaiki) |

## Database Migration

### Schema Versioning
Drift menggunakan `schemaVersion` integer untuk melacak versi database. Setiap perubahan schema (tambah tabel, tambah kolom, ubah constraint) HARUS menaikkan `schemaVersion` dan menambahkan migration step di `onUpgrade`.

### MigrationStrategy Pattern
```dart
@DriftDatabase(tables: [Transactions, Wallets, Categories, Budgets])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 5; // Increment untuk setiap schema change

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // Seed default data di sini
    },
    onUpgrade: (m, from, to) async {
      // Setiap migration step mengecek versi saat diperkenalkan
      if (from < 2) {
        await m.createTable(budgets);
      }
      if (from < 3) {
        await m.addColumn(budgets, budgets.userId);
        await m.createIndex(idxBudgetsUserId);
      }
      if (from < 4) {
        await m.createIndex(idxTransactionsUserDate);
      }
      if (from < 5) {
        // Contoh: menambahkan kolom baru
        await m.addColumn(transactions, transactions.notes);
      }
    },
  );
}
```

### Rules
- SELALU increment `schemaVersion` saat mengubah schema — jangan skip angka
- Setiap migration step HARUS idempotent dan menggunakan `if (from < N)` guard
- JANGAN pernah mengubah migration step yang sudah dirilis — hanya tambahkan step baru
- Test migrations dengan membuat database dari versi lama dan upgrade ke versi baru
- Jalankan `dart run build_runner build` setelah mengubah table definitions

### Destructive Migrations (Drop Table/Column)
Destructive migrations (drop table, drop column, rename table) memerlukan **explicit data backup logic** sebelum eksekusi:

```dart
if (from < 6) {
  // DESTRUCTIVE: dropping old_transactions table
  // Step 1: Backup data ke struktur baru
  final rows = await customSelect('SELECT * FROM old_transactions').get();
  for (final row in rows) {
    await into(transactions).insert(TransactionsCompanion.insert(
      description: row.read<String>('description'),
      amount: row.read<double>('amount'),
      // ... map remaining columns
    ));
  }
  // Step 2: Drop tabel lama HANYA setelah migration berhasil
  await m.deleteTable('old_transactions');
}
```

#### Rules untuk Destructive Migrations
- WAJIB backup data sebelum drop table — data loss tidak bisa di-undo
- Gunakan `customSelect` untuk membaca data dari tabel lama sebelum drop
- Pertimbangkan menambahkan flag di `SharedPreferences` untuk menandai migration berhasil
- Jika migration gagal di tengah jalan, app harus bisa retry tanpa corrupt data
- JANGAN drop table yang masih memiliki foreign key references aktif
- Untuk rename column: buat kolom baru → copy data → drop kolom lama (SQLite limitation)

## Theming System

### Preset System
App menggunakan `AppThemePreset` enum dengan 3 tema:
- `defaultPurple` — Clean minimal, blue accent
- `rosePine` — Warm rose/pine palette
- `cyberpunk` — Neon pink/cyan dark theme

### Rules
- Selalu gunakan `Theme.of(context).colorScheme` untuk warna, BUKAN hardcode
- Gunakan `context.theme.textTheme` untuk typography
- Card menggunakan border (bukan elevation/shadow) — sesuai design system
- Border radius standar: 16px untuk cards
- Background: transparent AppBar, no elevation

### Contoh yang BENAR:
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
    ),
  ),
)
```

### Contoh yang SALAH:
```dart
// ❌ Hardcoded colors
Container(color: Color(0xFF1A1A2E))

// ❌ Using elevation shadows instead of borders
Card(elevation: 4)

// ❌ Wrong border radius
borderRadius: BorderRadius.circular(8) // Harus 16
```

## Animation Guidelines

### flutter_animate Usage
```dart
// Stagger list items
ListView.builder(
  itemBuilder: (context, index) {
    return item
      .animate()
      .fadeIn(delay: Duration(milliseconds: index * 50))
      .slideY(begin: 0.1, end: 0);
  },
)
```

### Rules
- Durasi standar: 200-400ms untuk UI transitions
- Gunakan `Curves.easeOutCubic` sebagai default curve
- JANGAN animate terlalu banyak elemen sekaligus — max 5-8 stagger items
- Loading states: gunakan Shimmer package, bukan CircularProgressIndicator generik
- Lottie untuk animasi kompleks (empty states, celebrations, onboarding)
- `flutter_animate` untuk micro-interactions dan list animations

## Localization (i18n)

### Rules
- SEMUA user-facing string HARUS menggunakan `.tr()` dari easy_localization
- File translations di `assets/translations/{locale}.json`
- Format: `'key'.tr()` atau `'key'.tr(args: ['value'])`
- JANGAN hardcode string Indonesia atau English di widget

```dart
// ✅ Benar
Text('transaction.title'.tr())
Text('wallet.balance'.tr(args: [formattedAmount]))

// ❌ Salah
Text('Transaksi')
Text('Saldo: Rp 100.000')
```

## Security Patterns

### Anti-Tampering
- App memverifikasi waktu via NTP sebelum operasi sensitif
- Jika waktu device tidak sinkron → app terkunci
- PIN/biometric auth required saat app resume dari background

### Secure Storage
```dart
// Untuk data sensitif (tokens, keys)
final storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);

// Untuk preferences biasa (theme, locale)
final prefs = SharedPreferences.getInstance();
await prefs.setString('key', value);
```

### Rules
- JANGAN simpan financial data di SharedPreferences — gunakan Drift (encrypted jika perlu)
- JANGAN log sensitive data (amounts, account numbers) di debug mode
- Selalu validate input amounts (no negative, max limit)

## Deep Link Schema

The app uses the `duasaku://` URI scheme for navigating to specific screens from external sources (home screen widgets, notifications).

### Registered Routes

| Route | Purpose | Parameters | Source |
|-------|---------|------------|--------|
| `duasaku://new_transaction` | Opens the transaction entry bottom sheet for quick transaction creation | None | Home screen widget button |

### Route: `duasaku://new_transaction`

- **Purpose:** Allows users to quickly add a new transaction from the Android home screen widget without manually navigating through the app.
- **Behavior:** Sets `widgetLaunchProvider` to `true` and navigates to `/home`, which triggers the transaction entry bottom sheet.
- **Parameters:** None. The route uses only the host segment (`new_transaction`) with no query parameters.
- **Trigger:** Tapping the "New Transaction" button on the `DuaSakuWidgetProvider` Android widget.

### Naming Convention for New Routes

All new deep link routes MUST follow these rules:

1. **Scheme:** Always use `duasaku://` as the URI scheme.
2. **Path segments:** Use lowercase letters with underscore separators (snake_case).
   - ✅ `duasaku://new_transaction`
   - ✅ `duasaku://wallet_detail`
   - ✅ `duasaku://monthly_report`
   - ❌ `duasaku://newTransaction` (camelCase not allowed)
   - ❌ `duasaku://new-transaction` (hyphens not allowed)
   - ❌ `duasaku://NewTransaction` (PascalCase not allowed)
3. **Parameters:** Pass parameters as query strings when needed: `duasaku://wallet_detail?id=123`
4. **Registration:** Every new route MUST be documented in this section before implementation.
5. **Handler:** Route handling logic resides in `_handleWidgetClick` (or equivalent listener) in `main.dart`.

## Background Sync

### Workmanager-Based Task Scheduling

Background sync menggunakan `workmanager` package untuk menjadwalkan tugas periodik di luar lifecycle aplikasi. Semua background tasks didefinisikan di `lib/core/background/`.

#### Task Registration Pattern
```dart
import 'package:workmanager/workmanager.dart';

const String recurringTaskName = "com.duasaku.app.recurringTask";
const String oneOffSyncTaskName = "com.duasaku.app.oneOffSync";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case recurringTaskName:
        return await _handleRecurringSync();
      case oneOffSyncTaskName:
        return await _handleOneOffSync(inputData);
      default:
        return Future.value(false);
    }
  });
}

class BackgroundTaskHelper {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      "1",
      recurringTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
  }

  /// Schedule a one-off sync task (e.g., after bulk import)
  static Future<void> scheduleOneOffSync({Map<String, dynamic>? inputData}) async {
    await Workmanager().registerOneOffTask(
      "2",
      oneOffSyncTaskName,
      inputData: inputData,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
```

### Constraints

Background tasks HARUS menyertakan constraints yang sesuai:

| Constraint | Kapan Digunakan |
|-----------|----------------|
| `networkType: NetworkType.connected` | WAJIB untuk semua sync tasks yang membutuhkan koneksi internet |
| `requiresBatteryNotLow: true` | WAJIB untuk periodic tasks agar tidak menguras baterai |
| `requiresCharging: true` | Opsional — untuk heavy operations (bulk sync, data migration) |
| `requiresStorageNotLow: true` | Opsional — untuk tasks yang menulis banyak data ke disk |

#### Rules
- Periodic tasks: minimum frequency 15 menit (batasan Android WorkManager)
- Selalu gunakan `ExistingPeriodicWorkPolicy.keep` untuk menghindari duplikasi task
- One-off tasks: gunakan untuk operasi yang dipicu oleh user action (bukan jadwal)
- JANGAN jalankan heavy computation tanpa constraint `requiresBatteryNotLow: true`
- Background isolate TIDAK memiliki akses ke Riverpod providers — inisialisasi dependency secara manual

### Retry and Failure Handling

#### Retry Strategy
```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final db = AppDatabase();
      
      // Execute sync logic
      final success = await _performSync(db);
      
      await db.close();
      
      // Return true = task completed successfully
      // Return false = task failed, WorkManager will retry with backoff
      return Future.value(success);
    } catch (e) {
      debugPrint('[BackgroundSync] Task "$task" failed: $e');
      // Returning false triggers automatic retry with exponential backoff
      return Future.value(false);
    }
  });
}
```

#### Failure Handling Rules
- Return `true` dari `executeTask` → task selesai, tidak di-retry
- Return `false` dari `executeTask` → task gagal, WorkManager akan retry otomatis dengan exponential backoff
- Gunakan `backoffPolicy: BackoffPolicy.exponential` (default) untuk retry scheduling
- Maximum retry attempts ditentukan oleh OS (biasanya 3-5 kali)
- Setelah semua retry gagal, task di-drop — log failure untuk diagnostics
- JANGAN throw exception di dalam `executeTask` — selalu catch dan return `false`
- Untuk critical failures yang membutuhkan user attention, simpan error state ke local DB dan tampilkan saat app dibuka

#### Error Logging in Background Tasks
```dart
// ✅ Benar — gunakan debugPrint dengan prefix
debugPrint('[BackgroundSync] Sync completed: $recordCount records');
debugPrint('[BackgroundSync] Failed to sync: $e');

// ❌ Salah — print() tidak boleh digunakan
print('sync done');
print('error: $e');
```

## Financial App UX Patterns

### Transaction Entry
- Quick entry dari home widget (deep link: `duasaku://new_transaction`)
- Auto-parse dari notifikasi bank (NotificationParserService)
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

### Error Handling
- Tampilkan error inline (bukan dialog/snackbar untuk form errors)
- Retry mechanism untuk network operations
- Offline-first: semua data tersimpan lokal, sync saat online

## Code Style

### Naming Conventions
```dart
// Files: snake_case
transaction_repository.dart
wallet_notifier.dart

// Classes: PascalCase
class TransactionRepository {}
class WalletNotifier extends Notifier<WalletState> {}

// Variables/functions: camelCase
final totalBalance = ref.watch(balanceProvider);
Future<void> addTransaction(Transaction tx) async {}

// Constants: camelCase (Dart convention, NOT SCREAMING_CASE)
const defaultWalletName = 'Utama';
const maxTransactionAmount = 999999999.0;

// Providers: camelCase + Provider suffix
final transactionListProvider = ...
final walletNotifierProvider = ...
```

### Widget Structure
```dart
class TransactionCard extends ConsumerWidget {
  const TransactionCard({super.key, required this.transaction});
  
  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Container(
      // Widget tree...
    );
  }
}
```

### Rules
- Prefer `const` constructors wherever possible
- Extract widgets ke file terpisah jika > 80 lines
- Gunakan `ConsumerWidget` / `ConsumerStatefulWidget` (bukan Consumer wrapper)
- JANGAN nest lebih dari 5 level widget — extract ke method atau widget terpisah
- Selalu tambahkan `const` pada widget yang tidak berubah

## Testing Approach

- Unit tests untuk domain logic (use cases, entities)
- Widget tests untuk presentation components
- Integration tests untuk critical flows (add transaction, auth)
- Gunakan `flutter_test` + `mockito` untuk mocking
- Test file naming: `<feature>_test.dart`

## Performance

- Gunakan `const` widgets untuk menghindari unnecessary rebuilds
- `ListView.builder` (bukan `ListView`) untuk lists panjang
- `AutoDispose` providers untuk memory management
- Avoid rebuilding entire widget tree — gunakan `select` pada providers:
```dart
final balance = ref.watch(walletProvider.select((w) => w.balance));
```
- Image caching untuk assets yang sering digunakan
- Lazy loading untuk features yang jarang diakses
