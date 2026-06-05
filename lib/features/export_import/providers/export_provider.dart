import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:duasaku_app/core/local_db/app_database_provider.dart';
import 'package:duasaku_app/core/utils/result.dart';
import 'package:duasaku_app/features/auth/providers/auth_provider.dart';
import 'package:duasaku_app/features/export_import/data/export_import_repository.dart';
import 'package:duasaku_app/features/export_import/domain/export_import_repository_interface.dart';
import 'package:duasaku_app/features/export_import/domain/export_service_interface.dart';
import 'package:duasaku_app/features/export_import/domain/models/data_type.dart';
import 'package:duasaku_app/features/export_import/domain/models/export_config.dart';
import 'package:duasaku_app/features/export_import/domain/models/export_progress.dart';
import 'package:duasaku_app/features/export_import/domain/models/export_result.dart';
import 'package:duasaku_app/features/export_import/services/export_service.dart';

// ---------------------------------------------------------------------------
// Repository Provider
// ---------------------------------------------------------------------------

final exportImportRepositoryProvider =
    Provider<ExportImportRepositoryInterface>((ref) {
      final db = ref.watch(appDatabaseProvider);
      return ExportImportRepository(db);
    });

// ---------------------------------------------------------------------------
// Export Service Provider
// ---------------------------------------------------------------------------

final exportServiceProvider = Provider<ExportServiceInterface>((ref) {
  final repo = ref.watch(exportImportRepositoryProvider);
  final user = ref.watch(userProvider);
  final userId = user?.id ?? '';
  return ExportService(repo, userId: userId);
});

// ---------------------------------------------------------------------------
// Export State
// ---------------------------------------------------------------------------

/// Export mode: CSV report or full JSON backup.
enum ExportMode { csv, json }

/// State managed by [ExportNotifier].
class ExportState {
  final ExportMode mode;
  final Set<DataType> selectedTypes;
  final DateRangeFilter dateRange;
  final ExportProgress? progress;
  final ExportResult? result;
  final bool isExporting;

  const ExportState({
    this.mode = ExportMode.csv,
    this.selectedTypes = const {},
    this.dateRange = const ThisMonth(),
    this.progress,
    this.result,
    this.isExporting = false,
  });

  ExportState copyWith({
    ExportMode? mode,
    Set<DataType>? selectedTypes,
    DateRangeFilter? dateRange,
    ExportProgress? progress,
    ExportResult? result,
    bool? isExporting,
    bool clearProgress = false,
    bool clearResult = false,
  }) {
    return ExportState(
      mode: mode ?? this.mode,
      selectedTypes: selectedTypes ?? this.selectedTypes,
      dateRange: dateRange ?? this.dateRange,
      progress: clearProgress ? null : (progress ?? this.progress),
      result: clearResult ? null : (result ?? this.result),
      isExporting: isExporting ?? this.isExporting,
    );
  }
}

// ---------------------------------------------------------------------------
// Export Notifier
// ---------------------------------------------------------------------------

final exportNotifierProvider =
    AsyncNotifierProvider<ExportNotifier, ExportState>(() {
      return ExportNotifier();
    });

class ExportNotifier extends AsyncNotifier<ExportState> {
  @override
  Future<ExportState> build() async {
    return const ExportState();
  }

  /// Sets the export mode (CSV or JSON).
  void setMode(ExportMode mode) {
    final current = state.valueOrNull ?? const ExportState();
    state = AsyncData(
      current.copyWith(mode: mode, clearResult: true, clearProgress: true),
    );
  }

  /// Toggles a data type in the selection set.
  void toggleDataType(DataType type) {
    final current = state.valueOrNull ?? const ExportState();
    final updatedTypes = Set<DataType>.from(current.selectedTypes);
    if (updatedTypes.contains(type)) {
      updatedTypes.remove(type);
    } else {
      updatedTypes.add(type);
    }
    state = AsyncData(current.copyWith(selectedTypes: updatedTypes));
  }

  /// Sets the date range filter for CSV export.
  void setDateRange(DateRangeFilter dateRange) {
    final current = state.valueOrNull ?? const ExportState();
    state = AsyncData(current.copyWith(dateRange: dateRange));
  }

  /// Starts the export operation based on current mode and configuration.
  Future<void> startExport() async {
    final current = state.valueOrNull ?? const ExportState();
    final service = ref.read(exportServiceProvider);

    state = AsyncData(
      current.copyWith(
        isExporting: true,
        clearResult: true,
        clearProgress: true,
      ),
    );

    try {
      if (current.mode == ExportMode.csv) {
        // CSV export with selected types and date range
        if (current.selectedTypes.isEmpty) {
          state = AsyncData(current.copyWith(isExporting: false));
          return;
        }

        final config = ExportConfig(
          selectedTypes: current.selectedTypes,
          dateRange: current.dateRange,
        );

        final result = await service.exportCsv(config);
        switch (result) {
          case Success(:final value):
            state = AsyncData(
              current.copyWith(isExporting: false, result: value),
            );
          case Failure(:final error):
            state = AsyncError(error, StackTrace.current);
        }
      } else {
        // JSON full backup
        final result = await service.exportJsonBackup();
        switch (result) {
          case Success(:final value):
            state = AsyncData(
              current.copyWith(isExporting: false, result: value),
            );
          case Failure(:final error):
            state = AsyncError(error, StackTrace.current);
        }
      }
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }

  /// Shares the export result file via native share sheet.
  Future<void> shareResult() async {
    final current = state.valueOrNull;
    if (current?.result == null) return;

    final service = ref.read(exportServiceProvider);
    final result = current!.result!;

    final shareResult = await service.shareFile(
      result.filePath,
      result.mimeType,
    );

    switch (shareResult) {
      case Success():
        // Share completed successfully
        break;
      case Failure(:final error):
        state = AsyncError(error, StackTrace.current);
    }
  }
}
