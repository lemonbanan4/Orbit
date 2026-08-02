import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/routine_provider.dart';
import '../services/alchemy_telemetry_service.dart';
import '../theme/orbit_tokens.dart';

/// Surfaces the real habit co-occurrence data that AlchemyTelemetryService
/// already computes (previously only visible inside the premium Nebula Forge)
/// as a friendly "Alchemy Insights" card. Shows the strongest patterns between
/// the user's habits, or an encouraging empty state until there's enough logged
/// history. All values are genuine (computed from Habit.history) -- nothing
/// invented.
class AlchemyInsightsCard extends StatelessWidget {
  const AlchemyInsightsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final habits = context
        .watch<RoutineProvider>()
        .habits
        .values
        .where((h) => !h.isArchived)
        .toList();

    final synergies = AlchemyTelemetryService.computeSynergyMatrix(habits)
        .where((s) => s.synergyPercentage > 0)
        .toList()
      ..sort((a, b) => b.synergyPercentage.compareTo(a.synergyPercentage));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OrbitTokens.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OrbitTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: OrbitTokens.violet,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Alchemy Insights',
                style: TextStyle(
                  color: OrbitTokens.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (synergies.isEmpty)
            const _EmptyInsights()
          else
            ...synergies.take(2).map((s) => _SynergyRow(synergy: s)),
        ],
      ),
    );
  }
}

class _EmptyInsights extends StatelessWidget {
  const _EmptyInsights();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          const Text('🌌', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Keep logging your habits — as the stars align, Orbit will reveal '
              'the hidden patterns between them here.',
              style: TextStyle(
                color: OrbitTokens.inkDim,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SynergyRow extends StatelessWidget {
  final HabitSynergy synergy;
  const _SynergyRow({required this.synergy});

  @override
  Widget build(BuildContext context) {
    final strong = synergy.synergyPercentage >= 75;
    final accent = strong ? OrbitTokens.teal : OrbitTokens.gold;
    final pct = synergy.synergyPercentage;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  synergy.habitA,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: OrbitTokens.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.sync_alt_rounded,
                  color: OrbitTokens.inkFaint,
                  size: 16,
                ),
              ),
              Expanded(
                child: Text(
                  synergy.habitB,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: OrbitTokens.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${pct.round()}%',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: OrbitTokens.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            synergy.cosmicVerdict,
            style: TextStyle(
              color: OrbitTokens.inkDim,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
