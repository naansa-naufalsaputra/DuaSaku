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
import '../../../../core/widgets/glass/glass_card.dart';
import '../../../../core/widgets/glass/glass_button.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/widgets/glass/glass_app_bar.dart';
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

  void _showLanguagePicker(BuildContext context) {
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
                    ? const Icon(Icons.check_circle, color: Color(0xFF06B6D4))
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
                    ? const Icon(Icons.check_circle, color: Color(0xFF06B6D4))
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

  void _showParserModePicker(BuildContext context) {
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
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: Color(0xFF06B6D4)),
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
                    ? const Icon(Icons.check_circle, color: Color(0xFF06B6D4))
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
                    color: Colors.blue.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.model_training, color: Colors.blue),
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
                    ? const Icon(Icons.check_circle, color: Color(0xFF06B6D4))
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
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.code, color: Colors.orange),
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
                    ? const Icon(Icons.check_circle, color: Color(0xFF06B6D4))
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
                GlassButton(
                  variant: GlassButtonVariant.text,
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
                GlassButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(ctx).pop(true);
                  },
                  child: Text(
                    'profile.btn_overwrite'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  void _showRestoreSummarySheet(BuildContext context, Map<String, int> counts) {
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
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF06B6D4),
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
                    ),
                    _buildSummaryItem(
                      context,
                      'profile.stat_categories'.tr(),
                      counts['categories'] ?? 0,
                      Icons.category,
                    ),
                    _buildSummaryItem(
                      context,
                      'profile.stat_transactions'.tr(),
                      counts['transactions'] ?? 0,
                      Icons.receipt_long,
                    ),
                    _buildSummaryItem(
                      context,
                      'profile.stat_budgets'.tr(),
                      counts['budgets'] ?? 0,
                      Icons.pie_chart,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                GlassButton(
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
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF06B6D4), size: 24),
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

  Future<void> _handleBackup() async {
    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.exportData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('profile.backup_success_msg'.tr()),
            backgroundColor: const Color(0xFF06B6D4),
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

  Future<void> _handleRestore() async {
    final confirm = await _showOverwriteWarning(context);
    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final backupService = ref.read(backupServiceProvider);
      final counts = await backupService.importData();
      if (counts != null) {
        if (mounted) {
          _showRestoreSummarySheet(context, counts);
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

  void _showDisplayNameDialog(BuildContext context) {
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
              child: Text(
                'profile.btn_cancel'.tr(),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            GlassButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                ref
                    .read(displayNameProvider.notifier)
                    .setDisplayName(controller.text.trim());
                Navigator.of(ctx).pop();
              },
              child: Text(
                'goals.save'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text('profile.title'.tr()),
        scrollController: _scrollController,
      ),
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                // Header Section
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'profile.user_profile'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Achievements Group
                _buildGroupLabel(context, 'profile.achievements'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GlassCard(
                    enableBlur: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          context,
                          'profile.achievements_health'.tr(),
                          '${ref.watch(gamificationProvider).healthScore}',
                          Icons.favorite,
                          Colors.red,
                        ),
                        _buildStatItem(
                          context,
                          'profile.achievements_streak'.tr(),
                          '${ref.watch(gamificationProvider).currentStreak}',
                          Icons.local_fire_department,
                          Colors.orange,
                        ),
                        _buildStatItem(
                          context,
                          'profile.achievements_badges'.tr(),
                          '${ref.watch(gamificationProvider).unlockedBadges.length}',
                          Icons.military_tech,
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),

                // Account & Wallets Section
                _buildGroupLabel(context, 'profile.account'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GlassCard(
                    enableBlur: false,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Colors.blue,
                            ),
                          ),
                          title: Text('profile.manage_wallets'.tr()),
                          subtitle: Text('profile.manage_wallets_desc'.tr()),
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
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.category_outlined,
                              color: Colors.purple,
                            ),
                          ),
                          title: Text('profile.manage_categories'.tr()),
                          subtitle: Text('profile.manage_categories_desc'.tr()),
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
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: Colors.teal,
                            ),
                          ),
                          title: Text('profile.display_name'.tr()),
                          subtitle: Text(
                            ref.watch(displayNameProvider).isNotEmpty
                                ? ref.watch(displayNameProvider)
                                : 'profile.display_name_desc'.tr(),
                          ),
                          trailing: const Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showDisplayNameDialog(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 1. Keamanan Section
                _buildGroupLabel(context, 'profile.security'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GlassCard(
                    enableBlur: false,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.security_rounded),
                          title: Text('profile.security_toggle'.tr()),
                          subtitle: Text('profile.security_toggle_desc'.tr()),
                          trailing: Switch(
                            value: securityState.isSecurityEnabled,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(securityProvider.notifier)
                                  .setSecurityEnabled(val);
                            },
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        Opacity(
                          opacity: securityState.isSecurityEnabled ? 1.0 : 0.4,
                          child: ListTile(
                            enabled: securityState.isSecurityEnabled,
                            leading: const Icon(Icons.fingerprint),
                            title: Text('profile.biometric_lock'.tr()),
                            subtitle: Text('profile.biometric_desc'.tr()),
                            trailing: Switch(
                              value: securityState.isBiometricEnabled,
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
                        const Divider(height: 1, indent: 56),
                        Opacity(
                          opacity: securityState.isSecurityEnabled ? 1.0 : 0.4,
                          child: ListTile(
                            enabled: securityState.isSecurityEnabled,
                            leading: const Icon(Icons.lock_outline),
                            title: Text('profile.change_pin'.tr()),
                            subtitle: Text('profile.change_pin_desc'.tr()),
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
                ),

                // 2. Manajemen Data Section
                _buildGroupLabel(context, 'profile.data_management'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GlassCard(
                    enableBlur: false,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.cloud_download_outlined),
                          title: Text('profile.backup_data'.tr()),
                          subtitle: Text('profile.backup_desc'.tr()),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _handleBackup();
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.cloud_upload_outlined),
                          title: Text('profile.restore_data'.tr()),
                          subtitle: Text('profile.restore_desc'.tr()),
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _handleRestore();
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Estetika Section
                _buildGroupLabel(context, 'profile.aesthetics'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GlassCard(
                    enableBlur: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.dark_mode_outlined),
                            title: Text('profile.dark_mode'.tr()),
                            trailing: Switch(
                              value:
                                  ref.watch(themeNotifierProvider).themeMode ==
                                  ThemeMode.dark,
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
                          const Divider(height: 1, indent: 56),
                          ListTile(
                            leading: const Icon(Icons.palette_outlined),
                            title: Text('profile.aesthetic_presets'.tr()),
                            subtitle: Text(
                              'profile.aesthetic_desc'.tr(),
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 16.0,
                              right: 16.0,
                              bottom: 12.0,
                            ),
                            child: _buildPresetSelector(context, ref),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Preferences Section
                _buildGroupLabel(context, 'profile.preferences'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: GlassCard(
                    enableBlur: false,
                    child: Column(
                      children: [
                        // Parser Engine Setting
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF06B6D4,
                              ).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.bolt,
                              color: Color(0xFF06B6D4),
                            ),
                          ),
                          title: Text('profile.parser_engine'.tr()),
                          subtitle: Text(
                            parserMode == ParserMode.auto
                                ? 'profile.parser_mode_auto'.tr()
                                : parserMode == ParserMode.tfliteOnly
                                ? 'profile.parser_mode_tflite'.tr()
                                : 'profile.parser_mode_regex'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.grey[600],
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
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey[600],
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
                            _showParserModePicker(context);
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        // Geofencing Alerts Setting
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: Colors.red,
                            ),
                          ),
                          title: Text('profile.geofencing_alerts'.tr()),
                          subtitle: Text('profile.geofencing_alerts_desc'.tr()),
                          trailing: Switch(
                            value: geofencingAlertsEnabled,
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
                ),

                // 4. Umum Section
                _buildGroupLabel(context, 'profile.general'.tr()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: GlassCard(
                    enableBlur: false,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: Text('profile.notifications'.tr()),
                          trailing: Switch(
                            value: _notificationsEnabled,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _notificationsEnabled = val;
                              });
                            },
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.language_outlined),
                          title: Text('profile.language'.tr()),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.locale.languageCode == 'id'
                                    ? 'Indonesia'
                                    : 'English',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey[600],
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
                            _showLanguagePicker(context);
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        ListTile(
                          leading: const Icon(Icons.sync_alt),
                          title: Text('profile.interceptor'.tr()),
                          subtitle: Text(
                            _isInterceptorEnabled
                                ? 'profile.interceptor_on'.tr()
                                : 'profile.interceptor_off'.tr(),
                          ),
                          trailing: Switch(
                            value: _isInterceptorEnabled,
                            onChanged: (val) {
                              HapticFeedback.lightImpact();
                              if (val && !_isInterceptorEnabled) {
                                _requestInterceptorPermission();
                              } else if (!val && _isInterceptorEnabled) {
                                _requestInterceptorPermission();
                              }
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
                ),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: GlassButton(
                    variant: GlassButtonVariant.secondary,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(authRepositoryProvider).signOut();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.logout, color: Colors.redAccent),
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
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                ),
              ),
            ),
        ],
      ),
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
}
