import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../providers/export_provider.dart';
import '../widgets/data_type_selector.dart';
import '../widgets/date_range_picker.dart';
import '../widgets/export_progress_card.dart';
import '../widgets/security_warning_dialog.dart';

/// Main export screen with segmented control for CSV Report and Full Backup modes.
///
/// - CSV mode: shows DataTypeSelector + DateRangePicker + Export button
/// - JSON mode: shows info card + Export button (with SecurityWarningDialog)
/// - During export: shows progress, disables back navigation and export button
/// - After export: auto-opens Share Sheet
///
/// Requirements: 1.6, 2.2, 3.6, 3.8, 7.1, 7.2, 7.3, 7.7
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  @override
  void dispose() {
    // Cleanup temp files when leaving the screen
    // Use a microtask to avoid calling ref after dispose
    Future.microtask(() {
      // Note: cleanup is handled by the service layer
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exportState = ref.watch(exportNotifierProvider);
    final exportData = exportState.valueOrNull ?? const ExportState();
    final isExporting = exportData.isExporting;

    // Listen for export completion to auto-share
    ref.listen(exportNotifierProvider, (previous, next) {
      final prevData = previous?.valueOrNull;
      final nextData = next.valueOrNull;

      if (prevData?.isExporting == true &&
          nextData?.isExporting == false &&
          nextData?.result != null) {
        // Export completed, auto-share
        ref.read(exportNotifierProvider.notifier).shareResult();
      }
    });

    return PopScope(
      canPop: !isExporting,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: Text('export_import.export.title'.tr()),
          leading: isExporting
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
        ),
        body: Stack(
          children: [
            const PremiumBackground(),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Segmented control for mode selection
                    _ModeSelector(
                      currentMode: exportData.mode,
                      isExporting: isExporting,
                    ),
                    const SizedBox(height: 20),

                    // Mode-specific content
                    if (exportData.mode == ExportMode.csv) ...[
                      _CsvModeContent(exportData: exportData),
                    ] else ...[
                      _JsonModeContent(),
                    ],

                    const SizedBox(height: 24),

                    // Progress indicator during export
                    if (isExporting && exportData.progress != null) ...[
                      ExportProgressCard(progress: exportData.progress!),
                      const SizedBox(height: 24),
                    ] else if (isExporting) ...[
                      _LoadingIndicator(),
                      const SizedBox(height: 24),
                    ],

                    // Export button
                    _ExportButton(
                      exportData: exportData,
                      isExporting: isExporting,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Mode Selector ────────────────────────────────────────────────────────────

class _ModeSelector extends ConsumerWidget {
  final ExportMode currentMode;
  final bool isExporting;

  const _ModeSelector({required this.currentMode, required this.isExporting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'export_import.export.mode_csv'.tr(),
              isSelected: currentMode == ExportMode.csv,
              isEnabled: !isExporting,
              onTap: () => ref
                  .read(exportNotifierProvider.notifier)
                  .setMode(ExportMode.csv),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'export_import.export.mode_json'.tr(),
              isSelected: currentMode == ExportMode.json,
              isEnabled: !isExporting,
              onTap: () => ref
                  .read(exportNotifierProvider.notifier)
                  .setMode(ExportMode.json),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CSV Mode Content ─────────────────────────────────────────────────────────

class _CsvModeContent extends ConsumerWidget {
  final ExportState exportData;

  const _CsvModeContent({required this.exportData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label: Data Types
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'export_import.export.select_data_types'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DataTypeSelector(
          selectedTypes: exportData.selectedTypes,
          onChanged: (type, selected) {
            ref.read(exportNotifierProvider.notifier).toggleDataType(type);
          },
        ),
        const SizedBox(height: 20),

        // Section label: Date Range
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'export_import.export.date_range'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DateRangePickerWidget(
          filter: exportData.dateRange,
          onChanged: (filter) {
            ref.read(exportNotifierProvider.notifier).setDateRange(filter);
          },
        ),
      ],
    );
  }
}

// ─── JSON Mode Content ────────────────────────────────────────────────────────

class _JsonModeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      enableBlur: false,
      child: Column(
        children: [
          Icon(
            Icons.cloud_download_outlined,
            size: 48,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'export_import.export.json_info_title'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'export_import.export.json_info_description'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Loading Indicator ────────────────────────────────────────────────────────

class _LoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassCard(
      enableBlur: false,
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'export_import.progress.preparing'.tr(),
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Export Button ─────────────────────────────────────────────────────────────

class _ExportButton extends ConsumerWidget {
  final ExportState exportData;
  final bool isExporting;

  const _ExportButton({required this.exportData, required this.isExporting});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canExport;
    if (exportData.mode == ExportMode.csv) {
      canExport = exportData.selectedTypes.isNotEmpty && !isExporting;
    } else {
      canExport = !isExporting;
    }

    return GlassButton(
      isLoading: isExporting,
      onPressed: canExport ? () => _onExport(context, ref) : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.file_upload_outlined, size: 20),
          const SizedBox(width: 8),
          Text('export_import.export.button'.tr()),
        ],
      ),
    );
  }

  Future<void> _onExport(BuildContext context, WidgetRef ref) async {
    if (exportData.mode == ExportMode.json) {
      // Show security warning dialog first for JSON backup
      final acknowledged = await SecurityWarningDialog.show(context);
      if (!acknowledged) return;
    }

    ref.read(exportNotifierProvider.notifier).startExport();
  }
}
