import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'liquid_glass_theme.dart';

enum AppThemePreset {
  defaultPurple,
}

class ThemeState {
  final AppThemePreset preset;
  final ThemeMode themeMode;

  const ThemeState({
    required this.preset,
    required this.themeMode,
  });

  ThemeState copyWith({
    AppThemePreset? preset,
    ThemeMode? themeMode,
  }) {
    return ThemeState(
      preset: preset ?? this.preset,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeState>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeState> {
  static const _keyPreset = 'theme_preset';
  static const _keyMode = 'theme_mode';

  @override
  ThemeState build() {
    _loadFromPrefs();
    return ThemeState(
      preset: AppThemePreset.defaultPurple,
      themeMode: PlatformDispatcher.instance.platformBrightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
    );
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final presetIndex = prefs.getInt(_keyPreset) ?? AppThemePreset.defaultPurple.index;
      final modeIndex = prefs.getInt(_keyMode);
      final themeMode = modeIndex != null 
          ? ThemeMode.values[modeIndex] 
          : (PlatformDispatcher.instance.platformBrightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light);

      state = ThemeState(
        preset: AppThemePreset.values[presetIndex],
        themeMode: themeMode,
      );
    } catch (e) {
      debugPrint('[ThemeProvider] Error loading theme settings: $e');
    }
  }

  Future<void> updatePreset(AppThemePreset preset) async {
    state = state.copyWith(preset: preset);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPreset, preset.index);
    } catch (e) {
      debugPrint('[ThemeProvider] Error saving theme preset: $e');
    }
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyMode, mode.index);
    } catch (e) {
      debugPrint('[ThemeProvider] Error saving theme mode: $e');
    }
  }
}

class ThemeDetails {
  final ThemeData themeData;
  final Color glowColor1;
  final Color glowColor2;
  final Color baseBackgroundColor;
  final List<Color> heatmapColors;

  const ThemeDetails({
    required this.themeData,
    required this.glowColor1,
    required this.glowColor2,
    required this.baseBackgroundColor,
    required this.heatmapColors,
  });
}

class ThemePresets {
  static ThemeDetails getDetails(AppThemePreset preset, bool isDark) {
    // Both rosePine, cyberpunk, and defaultPurple are merged into the minimalist theme setup
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFFFFFFF);
    final Color surfaceColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7);
    final Color textColor = isDark ? const Color(0xFFF5F5F7) : const Color(0xFF1D1D1F);
    final Color accentColor = isDark ? const Color(0xFF9D7BFF) : const Color(0xFF5E17EB);
    
    final Color borderColor = isDark 
        ? Colors.white.withValues(alpha: 0.08) 
        : Colors.black.withValues(alpha: 0.04);

    return ThemeDetails(
      baseBackgroundColor: bgColor,
      glowColor1: isDark ? const Color(0x1A9D7BFF) : const Color(0x1A5E17EB),
      glowColor2: isDark ? const Color(0x0DFFFFFF) : const Color(0x0D000000),
      heatmapColors: [
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        accentColor.withValues(alpha: 0.2),
        accentColor.withValues(alpha: 0.45),
        accentColor.withValues(alpha: 0.75),
        accentColor,
      ],
      themeData: ThemeData(
        useMaterial3: true,
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: bgColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentColor,
          brightness: isDark ? Brightness.dark : Brightness.light,
          primary: accentColor,
          surface: surfaceColor,
          onSurface: textColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          titleTextStyle: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceColor,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          elevation: 0,
          backgroundColor: surfaceColor,
          indicatorColor: Colors.transparent, 
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: accentColor, size: 26);
            }
            return IconThemeData(color: textColor.withValues(alpha: 0.5), size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w600);
            }
            return TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w400);
          }),
        ),
        dividerTheme: DividerThemeData(
          color: borderColor,
          thickness: 1,
          space: 1,
        ),
        extensions: [
          isDark ? LiquidGlassTheme.defaultPurpleDark() : LiquidGlassTheme.defaultPurpleLight(),
        ],
      ),
    );
  }
}

