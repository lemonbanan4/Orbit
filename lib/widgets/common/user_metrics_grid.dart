import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'metric_card.dart';
import '../../theme/orbit_colors.dart';

class UserMetricsGrid extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final int completedMilestones;
  final int totalXp;

  const UserMetricsGrid({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.completedMilestones,
    required this.totalXp,
  });

  @override
  Widget build(BuildContext context) {
    final orbitColors = Theme.of(context).extension<OrbitColors>();
    final Color orbColor1 = orbitColors?.orbColor1 ?? const Color(0xFF00E5FF);
    final Color orbColor2 = orbitColors?.orbColor2 ?? const Color(0xFF7000FF);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: MetricCard(
                    title: 'Current\nStreak',
                    value: currentStreak.toString(),
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.orangeAccent)),
            const SizedBox(width: 16),
            Expanded(
                child: MetricCard(
                    title: 'Longest\nStreak',
                    value: longestStreak.toString(),
                    icon: Icons.emoji_events_rounded,
                    color: Colors.amber)),
          ],
        ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: MetricCard(
                    title: 'Milestones\nCompleted',
                    value: completedMilestones.toString(),
                    icon: Icons.explore_rounded,
                    color: orbColor1)),
            const SizedBox(width: 16),
            Expanded(
                child: MetricCard(
                    title: 'Total XP\nEarned',
                    value: totalXp.toString(),
                    icon: Icons.stars_rounded,
                    color: orbColor2)),
          ],
        ).animate().fade(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1),
      ],
    );
  }
}
