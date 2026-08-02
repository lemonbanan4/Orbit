import 'package:flutter/material.dart';

import '../data/cosmic_ranks.dart';
import '../theme/orbit_tokens.dart';
import 'common/stellar_planet.dart';

/// An 800x800 branded "Week in Review" graphic, rendered off-screen via
/// ShareService.captureOffscreenWidget and shared. Shows the week's real
/// numbers (streak, level + rank, consistency, 7-day bars). Purely a view --
/// all values are passed in from live providers.
class WeeklyRecapCard extends StatelessWidget {
  final int streak;
  final int level;
  final int weeklyConsistencyPct;
  final List<double> weekBars; // 7 entries, 0..1

  const WeeklyRecapCard({
    super.key,
    required this.streak,
    required this.level,
    required this.weeklyConsistencyPct,
    required this.weekBars,
  });

  @override
  Widget build(BuildContext context) {
    final rank = cosmicRankForLevel(level);

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
        children: [
          Positioned(
            top: -140,
            right: -140,
            child: _glow(OrbitTokens.teal, 420),
          ),
          Positioned(
            bottom: -160,
            left: -120,
            child: _glow(OrbitTokens.violet, 420),
          ),
          Padding(
            padding: const EdgeInsets.all(56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MY WEEK IN ORBIT',
                      style: TextStyle(
                        color: OrbitTokens.teal,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                    Text(
                      'Orbit',
                      style: TextStyle(
                        color: OrbitTokens.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                // Center: planet + rank
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const StellarPlanet(
                        variant: StellarPlanetVariant.core,
                        size: 200,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        rank.title,
                        style: const TextStyle(
                          color: OrbitTokens.ink,
                          fontSize: 46,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Level $level',
                        style: TextStyle(
                          color: OrbitTokens.teal,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat('🔥', '$streak', 'day streak'),
                    _weekBarsWidget(),
                    _stat('✓', '$weeklyConsistencyPct%', 'consistency'),
                  ],
                ),
                // Footer
                Center(
                  child: Text(
                    'orbitroutine.com',
                    style: TextStyle(
                      color: OrbitTokens.inkDim,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [c.withValues(alpha: 0.30), Colors.transparent],
          ),
        ),
      );

  Widget _stat(String emoji, String value, String label) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: OrbitTokens.ink,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(color: OrbitTokens.inkDim, fontSize: 20),
          ),
        ],
      );

  Widget _weekBarsWidget() {
    return SizedBox(
      width: 180,
      height: 110,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(weekBars.length, (i) {
          final v = weekBars[i].clamp(0.0, 1.0);
          return Container(
            width: 18,
            height: 20 + v * 84,
            decoration: BoxDecoration(
              color: v >= 0.99
                  ? OrbitTokens.teal
                  : OrbitTokens.teal.withValues(alpha: 0.35 + v * 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
          );
        }),
      ),
    );
  }
}
