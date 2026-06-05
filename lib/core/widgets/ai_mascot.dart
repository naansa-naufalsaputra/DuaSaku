import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AiMascot extends StatelessWidget {
  final double size;

  const AiMascot({super.key, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/animations/mascot.json',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Container(
              width: size * 0.8,
              height: size * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6366F1), // Indigo
                    Color(0xFF3B82F6), // Blue
                    Color(0xFF10B981), // Emerald
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: size * 0.4,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .scaleXY(begin: 0.92, end: 1.08, duration: 2000.ms, curve: Curves.easeInOut)
            .then()
            .shimmer(duration: 3000.ms, color: Colors.white.withValues(alpha: 0.3)),
          );
        },
      ),
    );
  }
}
