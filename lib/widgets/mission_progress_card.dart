import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/cosmic_ranks.dart';
import '../providers/routine_provider.dart';
import '../providers/telemetry_provider.dart';
import '../theme/orbit_tokens.dart';
import 'common/stellar_planet.dart';

/// A "Mission Progress" dashboard hero — a circular level-progress ring around a
/// glowing planet, with three live metric tiles beneath. All values are real
/// (TelemetryProvider level/XP + RoutineProvider streak/completion); nothing is
/// invented. First version of the dashboard-style telemetry look.
class MissionProgressCard extends StatelessWidget {
  const MissionProgressCard({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetry = context.watch<TelemetryProvider>();
    final routine = context.watch<RoutineProvider>();

    final level = telemetry.currentLevel;
    final rank = cosmicRankForLevel(level);
    final progress = telemetry.levelProgressFraction.clamp(0.0, 1.0);
    final streak = routine.currentStreak;
    final completion = routine.lifetimeCompletionRate; // 0..100

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF15112C), Color(0xFF0A0819)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: OrbitTokens.teal.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: OrbitTokens.teal.withValues(alpha: 0.08),
            blurRadius: 26,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                color: OrbitTokens.teal,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Mission Progress',
                style: TextStyle(
                  color: OrbitTokens.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: CustomPaint(
                painter: _RingPainter(progress: progress),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const StellarPlanet(
                        variant: StellarPlanetVariant.core,
                        size: 88,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'LEVEL $level',
                        style: const TextStyle(
                          color: OrbitTokens.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      Text(
                        rank.title,
                        style: const TextStyle(
                          color: OrbitTokens.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${(progress * 100).round()}% to next',
                        style: const TextStyle(
                          color: OrbitTokens.inkDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _MetricTile(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                value: '$streak',
                color: OrbitTokens.gold,
              ),
              const SizedBox(width: 10),
              _MetricTile(
                icon: Icons.bolt_rounded,
                label: 'Total XP',
                value: '${telemetry.globalXp}',
                color: OrbitTokens.teal,
              ),
              const SizedBox(width: 10),
              _MetricTile(
                icon: Icons.check_circle_rounded,
                label: 'Rate',
                value: '${completion.round()}%',
                color: OrbitTokens.violet,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draws the faint background track + the teal→blue progress arc.
class _RingPainter extends CustomPainter {
  final double progress;
  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 9;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..color = OrbitTokens.surface2;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: [
          OrbitTokens.teal,
          Color(0xFF5B8CFF),
          OrbitTokens.teal,
        ],
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: OrbitTokens.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: OrbitTokens.inkDim,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
