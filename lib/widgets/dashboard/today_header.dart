import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/routine_provider.dart';
import '../../theme/orbit_tokens.dart';

/// The dashboard hero from the redesign pitch: time-of-day greeting +
/// streak pill, followed by a progress ring summarizing how many of the
/// three routines are fully logged today.
class TodayHeader extends StatelessWidget {
  const TodayHeader({super.key});

  static const _routineTypes = ['Morning', 'Work', 'Night'];

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'GOOD MORNING';
    if (hour < 18) return 'GOOD AFTERNOON';
    return 'GOOD EVENING';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final dimColor = textColor.withValues(alpha: 0.55);
    final routineProvider = context.watch<RoutineProvider>();

    final displayName =
        FirebaseAuth.instance.currentUser?.displayName ?? 'Commander';
    final streak = routineProvider.currentStreak;

    // A routine counts as "logged" when it has habits and they're all done.
    final statuses = <String, bool>{
      for (final type in _routineTypes)
        type: () {
          final habits = routineProvider.getHabitsForRoutine(type);
          return habits.isNotEmpty && habits.every((h) => h.isCompleted);
        }(),
    };
    final doneCount = statuses.values.where((done) => done).length;
    final openRoutines = statuses.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    final String line1;
    final String line2;
    if (doneCount == _routineTypes.length) {
      line1 = 'All routines logged today';
      line2 = 'Your orbit is complete. 🎉';
    } else if (doneCount == 0) {
      line1 = 'No routines logged yet';
      line2 = 'Start with ${openRoutines.first.toLowerCase()}';
    } else {
      line1 =
          '${doneCount == 1 ? "One" : "Two"} routine${doneCount == 1 ? "" : "s"} logged today';
      line2 = openRoutines.length == 1
          ? '${openRoutines.first} routine still open'
          : '${openRoutines.join(" & ")} still open';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: TextStyle(
                      color: dimColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: OrbitTokens.surface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: OrbitTokens.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$streak',
                    style: const TextStyle(
                      color: OrbitTokens.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'day streak',
                    style: TextStyle(
                      color: dimColor,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            SizedBox(
              width: 78,
              height: 78,
              // Sweeps in from zero whenever the completed count changes —
              // the ring feels alive instead of stamped on.
              child: TweenAnimationBuilder<double>(
                key: ValueKey(doneCount),
                tween: Tween(
                  begin: 0,
                  end: doneCount / _routineTypes.length,
                ),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, animatedProgress, child) => CustomPaint(
                  painter: _RingPainter(
                    progress: animatedProgress,
                    trackColor: OrbitTokens.surface2,
                  ),
                  child: child,
                ),
                child: Center(
                  child: Text(
                    '$doneCount/${_routineTypes.length}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line1,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line2,
                    style: TextStyle(color: dimColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;

  _RingPainter({required this.progress, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      final shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: const [OrbitTokens.teal, OrbitTokens.violet],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);

      // Soft glow beneath the arc, then the crisp arc on top.
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 5
          ..strokeCap = StrokeCap.round
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..shader = shader,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
