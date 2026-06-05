# Implementation Plan: Export/Import Data

## Overview

Implementasi fitur Export/Import Data menggunakan Clean Architecture. Fitur ini memisahkan logika I/O dan serialisasi JSON/CSV ke Service Layer dengan eksekusi di Background Isolate, sementara operasi database dipusatkan di Data Layer (Drift). Menggunakan Riverpod untuk state management dan glados untuk Property-Based Testing.

## Tasks

- [x] 1. Domain Models & Core Setup
  - [x] 1.1 Buat Enum & Data Models Dasar
    - Buat `lib/features/export_import/domain/models/data_type.dart` dengan enum `DataType` (transactions, wallets, categories, budgets, recurringTransactions, goals, goalDeposits, budgetAlerts) beserta getter `dateColumn` (field `date` untuk Transactions, `createdAt` untuk lainnya)
    - Buat `lib/features/export_import/domain/models/export_config.dart` dengan class `ExportConfig` (selectedTypes, dateRange) dan sealed class `DateRangeFilter` beserta turunan: `AllTime`, `ThisMonth`, `LastMonth`, `Last3Months`, `ThisYear`, `CustomRange`
    - Buat `lib/features/export_import/domain/models/export_progress.dart` dengan class `ExportProgress` (percentage, currentTable, estimatedRemaining)
    - Buat `lib/features/export_import/domain/models/import_progress.dart` dengan class `ImportProgress` (percentage, currentTable, estimatedRemaining)
    - Buat `lib/features/export_import/domain/models/import_preview.dart` dengan class `ImportPreview` (metadata, walletCount, categoryCount, transactionCount, budgetCount, goalCount, recurringTransactionCount, budgetAlertCount, fileSizeBytes)
    - Buat `lib/features/export_import/domain/models/export_result.dart` dengan class `ExportResult` (filePath, mimeType, fileName, recordCount)
    - _Requirements: 1.1, 1.2, 2.1, 2.3, 3.1, 7.2_

  - [x] 1.2 Buat BackupMetadata Model
    - Buat `lib/features/export_import/domain/models/backup_metadata.dart` dengan class `BackupMetadata` (appVersion, schemaVersion, exportedAt, deviceId, exportedBy)
    - Implementasikan `toJson()` dan `fromJson()` yang ketat: validasi bahwa semua required fields ada, `exportedBy` harus bernilai `'duasaku'`, `exportedAt` harus format ISO 8601, `schemaVersion` harus positive integer
    - Tambahkan factory constructor `BackupMetadata.now()` yang otomatis mengisi `exportedAt` dengan timestamp saat ini dan `exportedBy` dengan `'duasaku'`
    - _Requirements: 3.2, 3.5, 4.1, 8.4_

- [x] 2. Domain Interfaces
  - [x] 2.1 Buat ExportImportRepositoryInterface
    - Buat `lib/features/export_import/domain/export_import_repository_interface.dart`
    - Definisikan fungsi read `get<Table>Raw` untuk ke-11 tabel (getWalletsRaw, getCategoriesRaw, getTransactionsRaw, getBudgetsRaw, getRecurringTransactionsRaw, getRecurringExecutionLogsRaw, getGoalsRaw, getGoalDepositsRaw, getBudgetAlertsRaw, getBudgetAlertPreferencesRaw, getBudgetAlertThresholdStatusRaw) — masing-masing return `Future<Result<List<Map<String, dynamic>>, AppError>>`
    - Definisikan fungsi join nama: `getWalletNameMap(String userId)` dan `getCategoryNameMap(String userId)` — return `Future<Result<Map<String, String>, AppError>>`
    - Definisikan fungsi `restoreFullBackup(Map<String, List<Map<String, dynamic>>> data)` — return `Future<Result<void, AppError>>`
    - Pastikan interface pure Dart (tidak import Drift atau Flutter packages)
    - _Requirements: 1.4, 3.1, 4.5, 8.5_

  - [x] 2.2 Buat Export & Import Service Interfaces
    - Buat `lib/features/export_import/domain/export_service_interface.dart` dengan methods: `exportCsv(ExportConfig config)`, `exportJsonBackup()`, `shareFile(String filePath, String mimeType)`, `cleanupTempFiles()`
    - Buat `lib/features/export_import/domain/import_service_interface.dart` dengan methods: `previewBackup(String filePath)`, `restoreBackup(String filePath, {required void Function(ImportProgress) onProgress})`
    - Pastikan semua return type menggunakan `Result<T, AppError>` (kecuali `cleanupTempFiles` yang void)
    - _Requirements: 1.2, 3.1, 4.3, 6.1_

- [x] 3. Data Layer (Drift Repository)
  - [x] 3.1 Implementasi ExportImportRepository
    - Buat `lib/features/export_import/data/export_import_repository.dart` yang mengimplementasikan `ExportImportRepositoryInterface`
    - Implementasikan query database menggunakan Drift `customSelect` untuk semua tabel — return data sebagai `List<Map<String, dynamic>>` (raw maps, bukan Drift objects)
    - Implementasikan date filtering pada query: gunakan WHERE clause dengan parameter `startDate` dan `endDate` (opsional) pada kolom yang sesuai per tipe data
    - Implementasikan `getWalletNameMap` dan `getCategoryNameMap` yang return Map<id, name> untuk resolusi FK di CSV
    - Implementasikan `restoreFullBackup` menggunakan `_db.transaction()`: hapus semua tabel dalam reverse FK order, lalu insert data baru sesuai urutan FK constraints (Wallets → Categories → Transactions → Budgets → RecurringTransactions → RecurringExecutionLogs → Goals → GoalDeposits → BudgetAlerts → BudgetAlertPreferences → BudgetAlertThresholdStatus)
    - Wrap semua operasi dalam try-catch, return `Failure(AppError.database(...))` pada error
    - _Requirements: 1.4, 2.3, 2.4, 3.1, 4.5, 5.3, 8.5_

- [x] 4. Service Layer (Isolates & I/O)
  - [x] 4.1 Buat Isolate Helpers (CSV & JSON Serialization)
    - Buat `lib/features/export_import/services/isolate_helpers.dart`
    - Implementasikan static function `generateCsvContent(List<Map<String, dynamic>> data, List<String> headers, {Map<String, String>? walletNames, Map<String, String>? categoryNames})` — return String CSV dengan UTF-8 BOM prefix (0xEF, 0xBB, 0xBF), header row, dan data rows. Untuk Transactions, resolve walletId/categoryId ke nama menggunakan maps yang diberikan
    - Implementasikan static function `serializeBackupToJson(Map<String, dynamic> backupData)` — return String JSON yang di-encode dengan `JsonEncoder.withIndent`
    - Implementasikan static function `parseAndValidateBackupJson(String jsonString, int currentSchemaVersion)` — return parsed Map atau throw error jika: malformed JSON, missing metadata, exportedBy bukan 'duasaku', schemaVersion mismatch, missing required fields, broken FK references
    - Semua fungsi HARUS pure (tidak import Drift, Riverpod, atau Flutter) agar aman di `Isolate.run`
    - _Requirements: 1.3, 1.4, 1.5, 3.2, 3.3, 4.1, 4.2, 4.7, 5.1, 5.2, 5.6, 8.2, 8.3_

  - [x] 4.2 Implementasi ExportService
    - Buat `lib/features/export_import/services/export_service.dart` yang mengimplementasikan `ExportServiceInterface`
    - `exportCsv`: panggil repository untuk data raw + name maps, jalankan `Isolate.run(() => generateCsvContent(...))` per tipe data, tulis file ke temp directory. Jika single type → file .csv langsung. Jika multiple types → buat ZIP archive menggunakan `archive` package
    - `exportJsonBackup`: panggil repository untuk semua 11 tabel, susun backup structure dengan metadata (gunakan `BackupMetadata.now()`), jalankan `Isolate.run(() => serializeBackupToJson(...))`, tulis ke temp file dengan nama format `duasaku_backup_{YYYY-MM-DD_HHmmss}.json`
    - `shareFile`: gunakan `SharePlus.instance.share(ShareParams(files: [XFile(filePath)]))` dengan MIME type yang sesuai (text/csv, application/zip, application/json)
    - `cleanupTempFiles`: hapus semua file di temp directory yang prefix-nya 'duasaku_' dan lebih tua dari 24 jam
    - Gunakan `path_provider` untuk `getTemporaryDirectory()`
    - _Requirements: 1.2, 1.5, 1.7, 3.1, 3.4, 3.7, 6.1, 6.2, 6.3, 6.4_

  - [x] 4.3 Implementasi ImportService
    - Buat `lib/features/export_import/services/import_service.dart` yang mengimplementasikan `ImportServiceInterface`
    - `previewBackup`: baca file, cek ekstensi (.json), cek ukuran file (>50MB → return warning), jalankan `Isolate.run(() => parseAndValidateBackupJson(...))` untuk validasi, return `ImportPreview` dengan counts per tabel
    - `restoreBackup`: baca file, parse ulang, panggil `repository.restoreFullBackup(data)`, report progress via callback per tabel yang di-insert
    - Handle semua error cases: file bukan JSON (ValidationError), malformed JSON (ValidationError), metadata invalid (ValidationError), schema mismatch (ValidationError dengan pesan berbeda untuk newer vs older), FK inconsistency (ValidationError), missing fields (ValidationError)
    - _Requirements: 4.1, 4.2, 4.3, 4.5, 4.6, 4.7, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

- [x] 5. Provider & State Management Layer
  - [x] 5.1 Buat Export & Import Providers
    - Buat `lib/features/export_import/providers/export_provider.dart`:
      - `exportImportRepositoryProvider` (Provider<ExportImportRepositoryInterface>)
      - `exportServiceProvider` (Provider<ExportServiceInterface>)
      - `exportNotifierProvider` (AsyncNotifierProvider<ExportNotifier, ExportState>) — manage state untuk mode selection (CSV/JSON), selected data types, date range filter, export progress, dan result
      - ExportNotifier methods: `setMode()`, `toggleDataType()`, `setDateRange()`, `startExport()`, `shareResult()`
    - Buat `lib/features/export_import/providers/import_provider.dart`:
      - `importServiceProvider` (Provider<ImportServiceInterface>)
      - `importNotifierProvider` (AsyncNotifierProvider<ImportNotifier, ImportState>) — manage state untuk file selection, preview, progress, dan result
      - ImportNotifier methods: `pickAndPreviewFile()`, `confirmRestore()`, `cancelImport()`
    - Implementasikan `_invalidateAllProviders()` di ImportNotifier yang di-call setelah restore berhasil — invalidate walletProvider, transactionListProvider, budgetProvider, goalNotifierProvider, recurringTransactionProvider, dan provider data lainnya
    - _Requirements: 4.8, 4.9, 7.1, 7.2, 7.3_

- [x] 6. Presentation (UI Liquid Glass)
  - [x] 6.1 Buat Helper Widgets
    - Buat `lib/features/export_import/presentation/widgets/data_type_selector.dart` — checkbox list untuk memilih DataType, disable export button jika tidak ada yang dipilih
    - Buat `lib/features/export_import/presentation/widgets/date_range_picker.dart` — dropdown/chips untuk preset (This Month default, Last Month, Last 3 Months, This Year, All Time) + Custom Range dengan date picker dialog
    - Buat `lib/features/export_import/presentation/widgets/export_progress_card.dart` — linear progress bar dengan label tabel yang sedang diproses dan estimasi waktu tersisa
    - Buat `lib/features/export_import/presentation/widgets/import_summary_card.dart` — card layout dengan ikon dan jumlah record per tipe data
    - Buat `lib/features/export_import/presentation/widgets/security_warning_dialog.dart` — modal dialog peringatan bahwa backup tidak terenkripsi, dengan tombol "Saya Mengerti" untuk melanjutkan
    - Terapkan Liquid Glass design: glassmorphism card dengan border, border radius 16px, warna dari `Theme.of(context).colorScheme`
    - _Requirements: 1.1, 1.6, 2.1, 2.2, 2.6, 3.6, 3.8, 7.2, 7.4, 7.7, 7.8_

  - [x] 6.2 Buat Export & Import Screens
    - Buat `lib/features/export_import/presentation/screens/export_screen.dart`:
      - Segmented control/tab untuk mode "CSV Report" dan "Full Backup (JSON)"
      - Mode CSV: tampilkan DataTypeSelector + DateRangePicker + Export button
      - Mode JSON: sembunyikan selector, tampilkan info "Seluruh data akan di-backup", tampilkan SecurityWarningDialog sebelum export
      - Progress indicator saat export berlangsung, disable back navigation dan export button
      - Setelah export selesai, otomatis buka Share Sheet
    - Buat `lib/features/export_import/presentation/screens/import_confirmation_screen.dart`:
      - Tampilkan ImportSummaryCard dengan preview data counts
      - Tampilkan destructive warning: "Proses restore akan menggantikan seluruh data yang ada"
      - Tombol "Cancel" (normal) dan "Restore" (merah/destructive)
      - Progress indicator saat import berlangsung dengan persentase dan nama tabel
      - Setelah restore berhasil, tampilkan pesan sukses dengan ringkasan
    - Daftarkan routes di go_router configuration
    - _Requirements: 1.6, 2.2, 3.6, 3.8, 4.3, 4.4, 4.8, 6.5, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_

- [x] 7. Property-Based Testing
  - [x] 7.1 Tulis Pengujian Properti (Glados)
    - Buat file test di `test/features/export_import/properties/`
    - **Property 1: Full Database Round-Trip** — export ke JSON lalu import kembali menghasilkan database state equivalent
    - **Property 2: BackupMetadata Serialization Round-Trip** — toJson() lalu fromJson() menghasilkan objek identical
    - **Property 3: CSV Output Count Matches Selection** — jumlah file CSV = jumlah DataType yang dipilih (single → .csv, multiple → .zip dengan N files)
    - **Property 4: CSV Structure Correctness** — UTF-8 BOM, header row, resolved names untuk Transactions
    - **Property 5: Date Range Filter Correctness** — hanya record dalam range yang ter-export, AllTime = semua record
    - **Property 6: Backup Completeness** — JSON backup memiliki metadata lengkap + data object dengan 11 tabel keys
    - **Property 7: Backup Filename Format** — nama file match pattern `duasaku_backup_{YYYY-MM-DD_HHmmss}.json`
    - **Property 8: Metadata Validation Rejects Invalid Files** — file tanpa metadata atau exportedBy bukan 'duasaku' ditolak
    - **Property 9: Schema Version Strict Match** — schemaVersion berbeda → import ditolak dengan pesan yang sesuai
    - **Property 10: Foreign Key Consistency Validation** — broken FK references → import ditolak dengan report tabel/record bermasalah
    - **Property 11: Required Fields Validation** — missing required fields → import ditolak dengan report field yang hilang
    - **Property 12: MIME Type Mapping Correctness** — single CSV → text/csv, multiple CSV → application/zip, JSON → application/json
    - Buat custom Glados generators: `validDatabaseState`, `validBackupMetadata`, `validDateRange`, `randomDataTypeSubset`, `malformedBackupJson`, `brokenFkBackup`
    - Minimum 100 iterasi per property test
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 1.2, 1.3, 1.4, 1.5, 1.7, 2.3, 2.4, 2.5, 3.1, 3.2, 3.4, 3.5, 4.1, 4.2, 4.7, 5.2, 5.6, 6.3, 6.4_

- [x] 8. Final Checkpoint
  - [x] 8.1 Full Test & Analyzer
    - Jalankan `flutter analyze` dan pastikan 0 issues terkait fitur export_import
    - Jalankan `flutter test test/features/export_import/` dan pastikan semua 12 property tests pass
    - Verifikasi bahwa export → share flow berjalan end-to-end (manual check atau integration test)
    - Verifikasi bahwa import → restore → UI refresh berjalan end-to-end

## Notes

- Setiap task mereferensi requirements spesifik untuk traceability
- Checkpoints memastikan validasi inkremental
- Property tests memvalidasi 12 correctness properties dari design document
- Semua repositories menggunakan abstract interfaces di domain layer
- Providers depend on abstract interface types, bukan concrete implementations
- glados library digunakan untuk property-based testing (minimum 100 iterasi)
- Background isolate hanya menerima plain Dart types (Map, List, String, int, double, bool)
- Semua user-facing strings harus menggunakan `.tr()` untuk lokalisasi
- Liquid Glass design: glassmorphism card, border radius 16px, borders bukan elevation
- File temporary dibersihkan setelah share atau saat app startup (stale >24 jam)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "2.2"] },
    { "id": 2, "tasks": ["3.1"] },
    { "id": 3, "tasks": ["4.1"] },
    { "id": 4, "tasks": ["4.2", "4.3"] },
    { "id": 5, "tasks": ["5.1"] },
    { "id": 6, "tasks": ["6.1"] },
    { "id": 7, "tasks": ["6.2"] },
    { "id": 8, "tasks": ["7.1"] },
    { "id": 9, "tasks": ["8.1"] }
  ]
}
```
