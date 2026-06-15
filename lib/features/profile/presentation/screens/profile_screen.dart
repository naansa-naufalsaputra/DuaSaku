import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/providers/auth_provider.dart';
import '../../../../core/security/security_service.dart';
import '../../../gamification/providers/gamification_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/premium_background.dart';
import '../../../../core/services/backup_service.dart';
import '../../../geofencing/providers/geofencing_alerts_provider.dart';
import '../../../transactions/domain/parser_mode.dart';
import '../../../transactions/providers/parser_mode_provider.dart';
import '../../providers/display_name_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with WidgetsBindingObserver {
  static const _managerChannel = MethodChannel(
    'com.duasaku.app/bank_notification_manager',
  );
  bool _isInterceptorEnabled = false;
  bool _isLoading = false;
  bool _notificationsEnabled = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInterceptorStatus();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkInterceptorStatus();
    }
  }

  Future<void> _checkInterceptorStatus() async {
    try {
      final isEnabled =
          await _managerChannel.invokeMethod<bool>('isPermissionGranted') ??
          false;
      if (mounted) {
        setState(() {
          _isInterceptorEnabled = isEnabled;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] Error checking interceptor status: $e');
    }
  }

  Future<void> _requestInterceptorPermission() async {
    try {
      await _managerChannel.invokeMethod('requestPermission');
    } catch (e) {
      debugPrint('[ProfileScreen] Error requesting interceptor permission: $e');
    }
  }

  void _showLanguagePicker(BuildContext context, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLang = context.locale.languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'profile.select_language'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Text('🇺🇸', style: TextStyle(fontSize: 28)),
                title: Text(
                  'English',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: currentLang == 'en'
                    ? Icon(Icons.check_circle, color: accentColor)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.setLocale(const Locale('en'));
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: const Text('🇮🇩', style: TextStyle(fontSize: 28)),
                title: Text(
                  'Bahasa Indonesia',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: currentLang == 'id'
                    ? Icon(Icons.check_circle, color: accentColor)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.setLocale(const Locale('id'));
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showParserModePicker(BuildContext context, Color accentColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentMode = ref.read(parserModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'profile.select_parser_mode'.tr(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt, color: accentColor),
                ),
                title: Text(
                  'profile.parser_mode_auto'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'profile.parser_mode_auto_desc'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                trailing: currentMode == ParserMode.auto
                    ? Icon(Icons.check_circle, color: accentColor)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(parserModeProvider.notifier)
                      .setMode(ParserMode.auto);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.model_training, color: accentColor),
                ),
                title: Text(
                  'profile.parser_mode_tflite'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'profile.parser_mode_tflite_desc'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                trailing: currentMode == ParserMode.tfliteOnly
                    ? Icon(Icons.check_circle, color: accentColor)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(parserModeProvider.notifier)
                      .setMode(ParserMode.tfliteOnly);
                  Navigator.of(ctx).pop();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.code, color: accentColor),
                ),
                title: Text(
                  'profile.parser_mode_regex'.tr(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'profile.parser_mode_regex_desc'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                trailing: currentMode == ParserMode.regexOnly
                    ? Icon(Icons.check_circle, color: accentColor)
                    : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(parserModeProvider.notifier)
                      .setMode(ParserMode.regexOnly);
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showOverwriteWarning(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await HapticFeedback.mediumImpact();
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'profile.overwrite_warning_title'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Text(
                'profile.overwrite_warning_content'.tr(),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop(false);
                  },
                  child: Text(
                    'profile.btn_cancel'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(ctx).pop(true);
                  },
                  child: Text(
                    'profile.btn_overwrite'.tr(),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showRestoreSummarySheet(
    BuildContext context,
    Map<String, int> counts,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: accentColor,
                      size: 36,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'profile.restore_success_title'.tr(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'profile.restore_success_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildSummaryItem(
                      context,
                      'profile.stat_wallets'.tr(),
                      counts['wallets'] ?? 0,
                      Icons.account_balance_wallet,
                      accentColor,
                    ),
                    _buildSummaryItem(
                      context,
                      'profile.stat_categories'.tr(),
                      counts['categories'] ?? 0,
                      Icons.category,
                      accentColor,
                    ),
                    _buildSummaryItem(
                      context,
                      'profile.stat_transactions'.tr(),
                      counts['transactions'] ?? 0,
                      Icons.receipt_long,
                      accentColor,
                    ),
                    _buildSummaryItem(
                      context,
                      'profile.stat_budgets'.tr(),
                      counts['budgets'] ?? 0,
                      Icons.pie_chart,
                      accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      'profile.btn_done'.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    int count,
    IconData icon,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: accentColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Future<void> _handleBackup(Color accentColor) async {
    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.exportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.backup_success_msg'.tr()),
            backgroundColor: accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.backup_fail_msg'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRestore(Color accentColor) async {
    final confirm = await _showOverwriteWarning(context);
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final counts = await backupService.importData();
      if (counts != null) {
        if (mounted) {
          _showRestoreSummarySheet(context, counts, accentColor);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.restore_fail_msg'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPresetSelector(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeNotifierProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final presets = [
      (
        AppThemePreset.defaultPurple,
        'Minimalist',
        Colors.deepPurple,
        Colors.indigo,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: presets.map((presetInfo) {
            final preset = presetInfo.$1;
            final label = presetInfo.$2;
            final color1 = presetInfo.$3;
            final color2 = presetInfo.$4;
            final isSelected = themeState.preset == preset;

            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(themeNotifierProvider.notifier).updatePreset(preset);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF16161B) : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color1,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color2,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showDisplayNameDialog(BuildContext context, Color accentColor) {
    final controller = TextEditingController(
      text: ref.read(displayNameProvider),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'profile.display_name'.tr(),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            maxLength: 20,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: 'profile.display_name_desc'.tr(),
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.black38,
              ),
              counterStyle: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(ctx).pop();
              },
              child: const Text(
                'profile.btn_cancel',
                style: TextStyle(color: Colors.grey),
              ).tr(),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(displayNameProvider.notifier)
                    .setDisplayName(controller.text.trim());
                Navigator.of(ctx).pop();
              },
              child: Text(
                'goals.save'.tr(),
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupContainer({
    required List<Widget> children,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTileIcon(IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: accentColor, size: 20),
    );
  }

  Widget _buildGroupLabel(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white60 : Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.grey,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final email = user?.email ?? 'Unknown Email';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final parserMode = ref.watch(parserModeProvider);
    final geofencingAlertsEnabled = ref.watch(geofencingAlertsProvider);
    final securityState = ref.watch(securityProvider);
    final accentColor = isDark
        ? const Color(0xFF0A84FF)
        : const Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'profile.title'.tr(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
              children: [
                // Header User Hero Section
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accentColor, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: accentColor.withValues(alpha: 0.1),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        ref.watch(displayNameProvider).isNotEmpty
                            ? ref.watch(displayNameProvider)
                            : 'local_user',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Achievements Group (Floated on Whitespace)
                _buildGroupLabel(context, 'profile.achievements'.tr()),
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        'profile.achievements_health'.tr(),
                        '${ref.watch(gamificationProvider).healthScore}',
                        Icons.favorite_rounded,
                        accentColor,
                      ),
                      _buildStatItem(
                        context,
                        'profile.achievements_streak'.tr(),
                        '${ref.watch(gamificationProvider).currentStreak}',
                        Icons.local_fire_department_rounded,
                        accentColor,
                      ),
                      _buildStatItem(
                        context,
                        'profile.achievements_badges'.tr(),
                        '${ref.watch(gamificationProvider).unlockedBadges.length}',
                        Icons.military_tech_rounded,
                        accentColor,
                      ),
                    ],
                  ),
                ),

                // Account & Wallets Section
                _buildGroupLabel(context, 'profile.account'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildGroupContainer(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.account_balance_wallet_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.manage_wallets'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'profile.manage_wallets_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/manage-wallets');
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.category_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.manage_categories'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'profile.manage_categories_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/categories');
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.person_outline,
                          accentColor,
                        ),
                        title: Text(
                          'profile.display_name'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          ref.watch(displayNameProvider).isNotEmpty
                              ? ref.watch(displayNameProvider)
                              : 'profile.display_name_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showDisplayNameDialog(context, accentColor);
                        },
                      ),
                    ],
                  ),
                ),

                // Keamanan Section
                _buildGroupLabel(context, 'profile.security'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildGroupContainer(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.security_rounded,
                          accentColor,
                        ),
                        title: Text(
                          'profile.security_toggle'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'profile.security_toggle_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: Switch.adaptive(
                          value: securityState.isSecurityEnabled,
                          activeTrackColor: accentColor,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            ref
                                .read(securityProvider.notifier)
                                .setSecurityEnabled(val);
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      Opacity(
                        opacity: securityState.isSecurityEnabled ? 1.0 : 0.4,
                        child: ListTile(
                          enabled: securityState.isSecurityEnabled,
                          leading: _buildTileIcon(
                            Icons.fingerprint,
                            accentColor,
                          ),
                          title: Text(
                            'profile.biometric_lock'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'profile.biometric_desc'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          trailing: Switch.adaptive(
                            value: securityState.isBiometricEnabled,
                            activeTrackColor: accentColor,
                            onChanged: securityState.isSecurityEnabled
                                ? (val) async {
                                    HapticFeedback.lightImpact();
                                    final success = await ref
                                        .read(securityProvider.notifier)
                                        .setBiometricEnabled(val);
                                    if (val && !success) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'profile.biometric_setup_failed'
                                                  .tr(),
                                            ),
                                            backgroundColor: Colors.redAccent,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : null,
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      Opacity(
                        opacity: securityState.isSecurityEnabled ? 1.0 : 0.4,
                        child: ListTile(
                          enabled: securityState.isSecurityEnabled,
                          leading: _buildTileIcon(
                            Icons.lock_outline,
                            accentColor,
                          ),
                          title: Text(
                            'profile.change_pin'.tr(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            'profile.change_pin_desc'.tr(),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onTap: securityState.isSecurityEnabled
                              ? () {
                                  HapticFeedback.lightImpact();
                                  context.push('/pin-auth?mode=change');
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),

                // Manajemen Data Section
                _buildGroupLabel(context, 'profile.data_management'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildGroupContainer(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.cloud_download_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.backup_data'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'profile.backup_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleBackup(accentColor);
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.cloud_upload_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.restore_data'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'profile.restore_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleRestore(accentColor);
                        },
                      ),
                    ],
                  ),
                ),

                // Estetika Section
                _buildGroupLabel(context, 'profile.aesthetics'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildGroupContainer(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.dark_mode_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.dark_mode'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: Switch.adaptive(
                          value:
                              ref.watch(themeNotifierProvider).themeMode ==
                              ThemeMode.dark,
                          activeTrackColor: accentColor,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            ref
                                .read(themeNotifierProvider.notifier)
                                .updateThemeMode(
                                  val ? ThemeMode.dark : ThemeMode.light,
                                );
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.palette_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.aesthetic_presets'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'profile.aesthetic_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: _buildPresetSelector(context, ref),
                      ),
                    ],
                  ),
                ),

                // Preferences Section
                _buildGroupLabel(context, 'profile.preferences'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildGroupContainer(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: _buildTileIcon(Icons.bolt, accentColor),
                        title: Text(
                          'profile.parser_engine'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          parserMode == ParserMode.auto
                              ? 'profile.parser_mode_auto'.tr()
                              : parserMode == ParserMode.tfliteOnly
                              ? 'profile.parser_mode_tflite'.tr()
                              : 'profile.parser_mode_regex'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              parserMode == ParserMode.auto
                                  ? 'Auto'
                                  : parserMode == ParserMode.tfliteOnly
                                  ? 'AI'
                                  : 'Regex',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showParserModePicker(context, accentColor);
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.location_on_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.geofencing_alerts'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'profile.geofencing_alerts_desc'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: Switch.adaptive(
                          value: geofencingAlertsEnabled,
                          activeTrackColor: accentColor,
                          onChanged: (val) async {
                            HapticFeedback.lightImpact();
                            final success = await ref
                                .read(geofencingAlertsProvider.notifier)
                                .toggleAlerts(val);
                            if (!success && val) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'profile.location_permission_required'
                                          .tr(),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Umum Section
                _buildGroupLabel(context, 'profile.general'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _buildGroupContainer(
                    isDark: isDark,
                    children: [
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.notifications_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.notifications'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: Switch.adaptive(
                          value: _notificationsEnabled,
                          activeTrackColor: accentColor,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            setState(() {
                              _notificationsEnabled = val;
                            });
                          },
                        ),
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      ListTile(
                        leading: _buildTileIcon(
                          Icons.language_outlined,
                          accentColor,
                        ),
                        title: Text(
                          'profile.language'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.locale.languageCode == 'id'
                                  ? 'Indonesia'
                                  : 'English',
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showLanguagePicker(context, accentColor);
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 56,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      ListTile(
                        leading: _buildTileIcon(Icons.sync_alt, accentColor),
                        title: Text(
                          'profile.interceptor'.tr(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          _isInterceptorEnabled
                              ? 'profile.interceptor_on'.tr()
                              : 'profile.interceptor_off'.tr(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                        trailing: Switch.adaptive(
                          value: _isInterceptorEnabled,
                          activeTrackColor: accentColor,
                          onChanged: (val) {
                            HapticFeedback.lightImpact();
                            _requestInterceptorPermission();
                          },
                        ),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _requestInterceptorPermission();
                        },
                      ),
                    ],
                  ),
                ),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? const Color(0xFF1C1C1E)
                          : Colors.white,
                      foregroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      side: BorderSide(
                        color: isDark
                            ? Colors.redAccent.withValues(alpha: 0.15)
                            : Colors.redAccent.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(authRepositoryProvider).signOut();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.logout,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'profile.logout'.tr(),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Center(
                  child: CircularProgressIndicator(color: accentColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
