import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/daily_mission.dart';
import '../providers/routine_provider.dart';
import '../providers/telemetry_provider.dart';
import '../theme/orbit_tokens.dart';
import 'telemetry_levelup_dialog.dart';

/// Dashboard card showing today's three daily missions with live progress and
/// a Claim button for each completed-but-unclaimed reward. All state lives in
/// RoutineProvider; this widget is purely a view.
class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        final missions = provider.dailyMissions;
        final claimable = provider.claimableMissionCount;

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
                    Icons.flag_circle_rounded,
                    color: OrbitTokens.gold,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Daily Missions',
                    style: TextStyle(
                      color: OrbitTokens.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (claimable > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: OrbitTokens.gold,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '$claimable ready',
                        style: const TextStyle(
                          color: OrbitTokens.ground,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              ...missions.map(
                (m) => _MissionRow(
                  mission: m,
                  progress: provider.missionProgress(m),
                  complete: provider.isMissionComplete(m),
                  claimed: provider.isMissionClaimed(m),
                  onClaim: () async {
                    HapticFeedback.mediumImpact();
                    // claimMission guards the once-per-day rule; only award the
                    // visible-level XP (and celebrate) if this call claimed it.
                    if (!provider.claimMission(m)) return;
                    final telemetry = context.read<TelemetryProvider>();
                    final didLevelUp = await telemetry.awardXp(m.rewardXp);
                    if (!context.mounted) return;
                    if (didLevelUp) {
                      TelemetryLevelUpDialog.show(
                        context,
                        telemetry.currentLevel,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('${m.title} claimed — +${m.rewardXp} XP'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MissionRow extends StatelessWidget {
  final DailyMission mission;
  final int progress;
  final bool complete;
  final bool claimed;
  final VoidCallback onClaim;

  const _MissionRow({
    required this.mission,
    required this.progress,
    required this.complete,
    required this.claimed,
    required this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final double pct =
        mission.target == 0 ? 1 : (progress / mission.target).clamp(0.0, 1.0);
    final Color accent = claimed
        ? OrbitTokens.inkFaint
        : (complete ? OrbitTokens.gold : OrbitTokens.teal);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Icon(
            claimed ? Icons.check_circle_rounded : mission.icon,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mission.title,
                        style: TextStyle(
                          color: claimed ? OrbitTokens.inkDim : OrbitTokens.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '+${mission.rewardXp} XP',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: OrbitTokens.surface2,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress/${mission.target}',
                      style: const TextStyle(
                        color: OrbitTokens.inkDim,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (complete && !claimed) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onClaim,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: OrbitTokens.gold,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'Claim',
                  style: TextStyle(
                    color: OrbitTokens.ground,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
