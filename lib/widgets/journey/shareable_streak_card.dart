import 'package:flutter/material.dart';
import '../../theme/orbit_tokens.dart';

/// A branded, square shareable graphic showing the user's current streak
/// and level — rendered entirely off-screen via
/// WidgetToImage.toImageOffscreen() (see ShareService.captureOffscreenWidget,
/// which existed with zero callers: a fully built "generate a custom
/// sharing graphic" pipeline with nothing in the app ever using it).
class ShareableStreakCard extends StatelessWidget {
  final int streak;
  final int level;

  const ShareableStreakCard({
    super.key,
    required this.streak,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 800,
      height: 800,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [OrbitTokens.ground, Color(0xFF1B1638)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    OrbitTokens.violet.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    OrbitTokens.teal.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: OrbitTokens.hairline),
                ),
                child: Text(
                  'LV.$level VOYAGER',
                  style: const TextStyle(
                    color: OrbitTokens.violet,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [OrbitTokens.teal, OrbitTokens.violet],
                ).createShader(bounds),
                child: Text(
                  '$streak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 220,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'DAY STREAK',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 64),
              const Text(
                'ORBIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
