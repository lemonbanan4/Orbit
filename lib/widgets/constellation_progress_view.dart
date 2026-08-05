import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/constellation.dart';
import '../providers/routine_provider.dart';
import '../theme/orbit_tokens.dart';
import 'common/stellar_planet.dart';

/// Shows the user's active AI-generated 4-week roadmap (a [Constellation]):
/// the goal, and all 4 weeks as a vertical trail -- past/active weeks show
/// the real habit, future weeks show a lock + unlock date (weeks are always
/// visible, per product decision, so the plan reads as one coherent arc).
class ConstellationProgressView extends StatelessWidget {
  final Constellation constellation;
  const ConstellationProgressView({super.key, required this.constellation});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            constellation.status == 'completed'
                ? 'CONSTELLATION COMPLETE'
                : 'YOUR CONSTELLATION',
            style: const TextStyle(
              color: OrbitTokens.teal,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            constellation.goal,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            constellation.status == 'completed'
                ? 'All 4 weeks ignited. Mission accomplished.'
                : 'Week ${constellation.currentWeek} of 4',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 24),
          for (final week in constellation.weeks) ...[
            _WeekCard(
              week: week,
              constellation: constellation,
              isActive:
                  week.week == constellation.currentWeek &&
                  constellation.status == 'active',
              isPast: week.week < constellation.currentWeek,
            ),
            if (week.week != 4) const SizedBox(height: 12),
          ],
          const SizedBox(height: 28),
          if (constellation.status == 'active')
            Center(
              child: TextButton(
                onPressed: () => _confirmAbandon(context),
                child: Text(
                  'Abandon Constellation',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmAbandon(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F1235),
        title: const Text(
          'Abandon this Constellation?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Habits already ignited stay in your routine -- only future weeks '
          'stop unlocking. You can start a new Constellation anytime.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(dialogContext);
              context.read<RoutineProvider>().abandonConstellation();
            },
            child: const Text(
              'Abandon',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final ConstellationWeek week;
  final Constellation constellation;
  final bool isActive;
  final bool isPast;

  const _WeekCard({
    required this.week,
    required this.constellation,
    required this.isActive,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    final isLocked = week.habitId == null && !isActive;
    final accent = isActive
        ? OrbitTokens.teal
        : (isPast ? OrbitTokens.gold : Colors.white24);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? OrbitTokens.teal.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: isLocked ? 0.15 : 0.4)),
      ),
      child: Row(
        children: [
          isLocked
              ? Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white38,
                    size: 22,
                  ),
                )
              : StellarPlanet(
                  variant: _variantForIcon(week.icon),
                  size: 56,
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'WEEK ${week.week}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    if (isPast) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: OrbitTokens.gold,
                        size: 14,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  week.habitTitle,
                  style: TextStyle(
                    color: isLocked ? Colors.white38 : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isLocked
                      ? 'Unlocks ${_formatDate(constellation.unlockDateForWeek(week.week))}'
                      : week.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: isLocked ? 0.4 : 0.55),
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  StellarPlanetVariant _variantForIcon(String icon) {
    switch (icon) {
      case 'Fitness':
        return StellarPlanetVariant.fitness;
      case 'Mind':
        return StellarPlanetVariant.mind;
      case 'Book':
      case 'Structure':
        return StellarPlanetVariant.productivity;
      case 'Explore':
        return StellarPlanetVariant.growth;
      default:
        return StellarPlanetVariant.core;
    }
  }
}
