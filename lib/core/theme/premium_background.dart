import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'theme_provider.dart';

class PremiumBackground extends ConsumerStatefulWidget {
  const PremiumBackground({super.key});

  @override
  ConsumerState<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends ConsumerState<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  // Smoothed sensor readings for low-pass filter
  double _smoothedX = 0.0;
  double _smoothedY = 0.0;

  @override
  void initState() {
    super.initState();

    // Slow continuous float animation (20 seconds cycle)
    _floatController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Listen to accelerometer with low-pass filter (alpha = 0.1)
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        if (!mounted) return;
        setState(() {
          // Low-pass filter: smooths out jittery sensor movement
          _smoothedX = _smoothedX * 0.9 + event.x * 0.1;
          _smoothedY = _smoothedY * 0.9 + event.y * 0.1;
        });
      },
      onError: (error) {
        debugPrint('[PremiumBackground] Accelerometer sensor error: $error');
      },
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeDetails = ThemePresets.getDetails(themeState.preset, isDark);
    final disableBlur =
        MediaQuery.highContrastOf(context) ||
        MediaQuery.accessibleNavigationOf(context);

    if (disableBlur) {
      return RepaintBoundary(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.alphaBlend(
                  themeDetails.glowColor1,
                  themeDetails.baseBackgroundColor,
                ),
                Color.alphaBlend(
                  themeDetails.glowColor2,
                  themeDetails.baseBackgroundColor,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Custom Cyan/Teal accent color for Blob 3 to enrich the darkmatter neon visual blend
    final Color cyberCyanGlow = isDark
        ? const Color(0x1506B6D4) // Subtle cyber cyan in dark mode
        : const Color(0x0F06B6D4); // Even subtler in light mode

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          // Compute float coordinates using trigonometric functions
          final double time = _floatController.value * 2 * math.pi;

          final double floatX1 = math.sin(time) * 25.0;
          final double floatY1 = math.cos(time) * 20.0;

          final double floatX2 = math.cos(time + 1.5) * 30.0;
          final double floatY2 = math.sin(time + 1.5) * 25.0;

          final double floatX3 = math.sin(time + 3.0) * 20.0;
          final double floatY3 = math.cos(time + 3.0) * 25.0;

          // Accelerometer parallax coefficients:
          // We shift coordinates based on sensor tilt. x governs horizontal tilt, y governs vertical.
          final double dx1 = _smoothedX * -12.0 + floatX1;
          final double dy1 = _smoothedY * 12.0 + floatY1;

          final double dx2 = _smoothedX * 18.0 + floatX2;
          final double dy2 = _smoothedY * -18.0 + floatY2;

          final double dx3 = _smoothedX * -8.0 + floatX3;
          final double dy3 = _smoothedY * -8.0 + floatY3;

          return Stack(
            children: [
              // Base background
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF9FBFF), // Pale pastel blue
                            Color(0xFFFFFFFF), // Pure white
                          ],
                        ),
                  color: isDark ? themeDetails.baseBackgroundColor : null,
                ),
              ),

              // Top right glow (Blob 1 - Theme Accent)
              Positioned(
                top: -100 + dy1,
                right: -50 + dx1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    color: isDark ? themeDetails.glowColor1 : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Bottom left glow (Blob 2 - Faint glow)
              Positioned(
                bottom: -50 + dy2,
                left: -100 + dx2,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    color: isDark ? themeDetails.glowColor2 : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Center right/middle glow (Blob 3 - Cyber Cyan Accent)
              Positioned(
                top: 220 + dy3,
                right: -80 + dx3,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: isDark ? cyberCyanGlow : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Blur Filter to create the glassmorphism glow effect
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isDark ? 80 : 0, // No blur needed in clean light mode
                  sigmaY: isDark ? 80 : 0,
                ),
                child: Container(color: Colors.transparent),
              ),
            ],
          );
        },
      ),
    );
  }
}
