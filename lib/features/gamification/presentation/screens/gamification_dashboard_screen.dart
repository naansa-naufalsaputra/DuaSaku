import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/premium_background.dart';
import '../../../../core/widgets/glass/glass_card.dart';
import '../../providers/gamification_provider.dart';

class BadgeData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color activeColor;

  const BadgeData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.activeColor,
  });
}

class GamificationDashboardScreen extends ConsumerWidget {
  const GamificationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gamificationState = ref.watch(gamificationProvider);

    final accentColor = isDark
        ? const Color(0xFF0A84FF)
        : const Color(0xFF007AFF);

    // Normalize 5-dimension sub-scores to percentage (0 - 100)
    final budgetPct = gamificationState.scoreBudget > 0
        ? (gamificationState.scoreBudget / 40.0) * 100.0
        : 0.0;
    final savingPct = gamificationState.scoreSaving > 0
        ? (gamificationState.scoreSaving / 30.0) * 100.0
        : 0.0;
    final streakPct = gamificationState.scoreStreak > 0
        ? (gamificationState.scoreStreak / 20.0) * 100.0
        : 0.0;
    final walletPct = gamificationState.scoreWallet > 0
        ? (gamificationState.scoreWallet / 5.0) * 100.0
        : 0.0;
    final goalPct = gamificationState.scoreGoal > 0
        ? (gamificationState.scoreGoal / 5.0) * 100.0
        : 0.0;

    final badgeList = [
      BadgeData(
        id: 'streak_7',
        title: 'gamification.streak_badge_title'.tr(),
        description: 'gamification.streak_badge_desc'.tr(),
        icon: Icons.local_fire_department_rounded,
        activeColor: const Color(0xFFFF9500),
      ),
      BadgeData(
        id: 'healthy_80',
        title: 'gamification.healthy_badge_title'.tr(),
        description: 'gamification.healthy_badge_desc'.tr(),
        icon: Icons.favorite_rounded,
        activeColor: const Color(0xFF34C759),
      ),
      BadgeData(
        id: 'saver_master',
        title: 'gamification.saver_badge_title'.tr(),
        description: 'gamification.saver_badge_desc'.tr(),
        icon: Icons.workspace_premium_rounded,
        activeColor: const Color(0xFFFFD60A),
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const PremiumBackground(),
          SafeArea(
            child: Column(
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          context.pop();
                        },
                      ),
                      Expanded(
                        child: Text(
                          'gamification.title'.tr(),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48), // Balancing spacer
                    ],
                  ),
                ),
                
                // Content Scroll View
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      // Radar Chart Section
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                          child: Column(
                            children: [
                              Text(
                                'insights.overall_health'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 200,
                                child: RadarChart(
                                  RadarChartData(
                                    radarShape: RadarShape.polygon,
                                    dataSets: [
                                      RadarDataSet(
                                        fillColor: accentColor.withValues(alpha: 0.15),
                                        borderColor: accentColor,
                                        entryRadius: 4,
                                        borderWidth: 2,
                                        dataEntries: [
                                          RadarEntry(value: budgetPct),
                                          RadarEntry(value: savingPct),
                                          RadarEntry(value: streakPct),
                                          RadarEntry(value: walletPct),
                                          RadarEntry(value: goalPct),
                                        ],
                                      ),
                                    ],
                                    radarBorderData: BorderSide(
                                      color: isDark ? Colors.white24 : Colors.black12,
                                      width: 1.5,
                                    ),
                                    gridBorderData: BorderSide(
                                      color: isDark ? Colors.white10 : Colors.black12,
                                      width: 1,
                                    ),
                                    tickBorderData: BorderSide(
                                      color: isDark ? Colors.white10 : Colors.black12,
                                      width: 1,
                                    ),
                                    ticksTextStyle: TextStyle(
                                      color: isDark ? Colors.white30 : Colors.black38,
                                      fontSize: 8,
                                    ),
                                    tickCount: 4,
                                    getTitle: (index, angle) {
                                      switch (index) {
                                        case 0:
                                          return RadarChartTitle(
                                            text: 'gamification.radar_budget'.tr(),
                                            angle: angle,
                                          );
                                        case 1:
                                          return RadarChartTitle(
                                            text: 'gamification.radar_saving'.tr(),
                                            angle: angle,
                                          );
                                        case 2:
                                          return RadarChartTitle(
                                            text: 'gamification.radar_streak'.tr(),
                                            angle: angle,
                                          );
                                        case 3:
                                          return RadarChartTitle(
                                            text: 'gamification.radar_wallet'.tr(),
                                            angle: angle,
                                          );
                                        case 4:
                                          return RadarChartTitle(
                                            text: 'gamification.radar_goal'.tr(),
                                            angle: angle,
                                          );
                                        default:
                                          return const RadarChartTitle(text: '');
                                      }
                                    },
                                    titlePositionPercentageOffset: 0.15,
                                    titleTextStyle: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.black87,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Score Breakdown
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        '${gamificationState.healthScore}',
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: accentColor,
                                        ),
                                      ),
                                      Text(
                                        'gamification.overall_score'.tr(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 36,
                                    color: isDark ? Colors.white24 : Colors.black12,
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        '${gamificationState.currentStreak}',
                                        style: const TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF9500),
                                        ),
                                      ),
                                      Text(
                                        'profile.achievements_streak'.tr(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white54 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Badges List
                      Text(
                        'profile.achievements_badges'.tr().toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: badgeList.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final badge = badgeList[index];
                          final isUnlocked = gamificationState.unlockedBadges.contains(badge.id);
                          
                          final iconColor = isUnlocked ? badge.activeColor : Colors.grey;
                          final bgColor = isUnlocked 
                              ? badge.activeColor.withValues(alpha: 0.1) 
                              : Colors.grey.withValues(alpha: 0.08);

                          return Opacity(
                            opacity: isUnlocked ? 1.0 : 0.4,
                            child: GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        badge.icon,
                                        color: iconColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            badge.title,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            badge.description,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isUnlocked 
                                          ? 'gamification.unlocked_badge'.tr() 
                                          : 'gamification.locked_badge'.tr(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isUnlocked 
                                            ? badge.activeColor 
                                            : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
