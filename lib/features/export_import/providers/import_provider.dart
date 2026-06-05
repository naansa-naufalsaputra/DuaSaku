import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/export_import/domain/import_service_interface.dart';
import 'package:duasaku_app/features/export_import/domain/models/import_preview.dart';
import 'package:duasaku_app/features/export_import/domain/models/import_progress.dart';
import 'package:duasaku_app/features/export_import/providers/export_provider.dart';
import 'package:duasaku_app/features/export_import/services/import_service.dart';
import 'package:duasaku_app/features/goals/providers/goal_provider.dart';
import 'package:duasaku_app/features/recurring_transactions/providers/recurring_transaction_provider.dart';
import 'package:duasaku_app/features/transactions/providers/budget_provider.dart';
import 'package:duasaku_app/features/transactions/providers/category_provider.dart';
import 'package:duasaku_app/features/transactions/providers/transaction_provider.dart';
import 'package:duasaku_app/features/wallets/providers/wallet_provider.dart';

// ---------------------------------------------------------------------------
// Import Service Provider
// ---------------------------------------------------------------------------

final importServiceProvider = Provider<ImportServiceInterface>((ref) {
  final repo = ref.watch(exportImportRepositoryProvider);
  return ImportService(repo, currentSchemaVersion: 7);
});

// ---------------------------------------------------------------------------
// Import State
// ---------------------------------------------------------------------------

/// State managed by [ImportNotifier].
class ImportState {
  final String? filePath;
  final ImportPreview? preview;
  final ImportProgress? progress;
  final bool isRestoring;
  final bool restoreComplete;

  const ImportState({
    this.filePath,
    this.preview,
    this.progress,
    this.isRestoring = false,
    this.restoreComplete = false,
  });

  ImportState copyWith({
    String? filePath,
    ImportPreview? preview,
    ImportProgress? progress,
    bool? isRestoring,
    bool? restoreComplete,
    bool clearFilePath = false,
    bool clearPreview = false,
    bool clearProgress = false,
  }) {
    return ImportState(
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      preview: clearPreview ? null : (preview ?? this.preview),
      progress: clearProgress ? null : (progress ?? this.progress),
      isRestoring: isRestoring ?? this.isRestoring,
      restoreComplete: restoreComplete ?? this.restoreComplete,
    );
  }
}

// ---------------------------------------------------------------------------
// Import Notifier
// ---------------------------------------------------------------------------

final importNotifierProvider =
    AsyncNotifierProvider<ImportNotifier, ImportState>(() {
      return ImportNotifier();
    });

class ImportNotifier extends AsyncNotifier<ImportState> {
  @override
  Future<ImportState> build() async {
    return const ImportState();
  }

  /// Opens file picker for JSON backup files and previews the selected file.
  Future<void> pickAndPreviewFile() async {
    final service = ref.read(importServiceProvider);

    // Open file picker for JSON files
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    // Update state with selected file path
    final current = state.valueOrNull ?? const ImportState();
    state = AsyncData(
      current.copyWith(
        filePath: filePath,
        clearPreview: true,
        clearProgress: true,
        restoreComplete: false,
      ),
    );

    // Preview the backup file
    final previewResult = await service.previewBackup(filePath);
    switch (previewResult) {
      case Success(:final value):
        state = AsyncData(current.copyWith(filePath: filePath, preview: value));
      case Failure(:final error):
        state = AsyncError(error, StackTrace.current);
    }
  }

  /// Confirms and executes the restore operation.
  ///
  /// This is a destructive operation that replaces all existing data.
  Future<void> confirmRestore() async {
    final current = state.valueOrNull ?? const ImportState();
    if (current.filePath == null) return;

    final service = ref.read(importServiceProvider);

    state = AsyncData(
      current.copyWith(
        isRestoring: true,
        clearProgress: true,
        restoreComplete: false,
      ),
    );

    final restoreResult = await service.restoreBackup(
      current.filePath!,
      onProgress: (progress) {
        final latest = state.valueOrNull ?? current;
        state = AsyncData(
          latest.copyWith(progress: progress, isRestoring: true),
        );
      },
    );

    switch (restoreResult) {
      case Success():
        _invalidateAllProviders();
        state = AsyncData(
          current.copyWith(
            isRestoring: false,
            restoreComplete: true,
            clearProgress: true,
          ),
        );
      case Failure(:final error):
        state = AsyncError(error, StackTrace.current);
    }
  }

  /// Cancels the import operation and resets state.
  void cancelImport() {
    state = const AsyncData(ImportState());
  }

  /// Invalidates all data providers after a successful restore
  /// so the UI refreshes with the newly imported data.
  void _invalidateAllProviders() {
    ref.invalidate(walletProvider);
    ref.invalidate(transactionNotifierProvider);
    ref.invalidate(budgetNotifierProvider);
    ref.invalidate(goalNotifierProvider);
    ref.invalidate(recurringTransactionNotifierProvider);
    ref.invalidate(categoryNotifierProvider);
  }
}
