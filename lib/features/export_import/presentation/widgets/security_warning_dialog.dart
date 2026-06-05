import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/widgets/glass/glass_dialog.dart';

/// A modal dialog warning the user that the backup file is not encrypted
/// and contains sensitive financial data.
///
/// Returns `true` if the user acknowledges the warning ("Saya Mengerti"),
/// or `false` if the dialog is dismissed/cancelled.
class SecurityWarningDialog extends StatelessWidget {
  const SecurityWarningDialog({super.key});

  /// Shows the security warning dialog and returns whether the user
  /// acknowledged the warning.
  static Future<bool> show(BuildContext context) async {
    final result = await showGlassDialog<bool>(
      context,
      barrierDismissible: false,
      dialog: GlassDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              'export_import.security_warning.title'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
        content: Text(
          'export_import.security_warning.message'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          GlassButton(
            variant: GlassButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('export_import.security_warning.cancel'.tr()),
          ),
          GlassButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('export_import.security_warning.acknowledge'.tr()),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GlassDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error, size: 28),
          const SizedBox(width: 8),
          Text(
            'export_import.security_warning.title'.tr(),
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ],
      ),
      content: Text(
        'export_import.security_warning.message'.tr(),
        textAlign: TextAlign.center,
        style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
      ),
      actions: [
        GlassButton(
          variant: GlassButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('export_import.security_warning.cancel'.tr()),
        ),
        GlassButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('export_import.security_warning.acknowledge'.tr()),
        ),
      ],
    );
  }
}
