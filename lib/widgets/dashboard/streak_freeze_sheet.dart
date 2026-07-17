import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/routine_provider.dart';
import '../../theme/orbit_tokens.dart';

/// A small snowflake chip showing how many streak freezes the user holds.
/// Tapping opens the purchase sheet. Sits next to the streak pill in
/// [TodayHeader] — freezes were a fully wired backend feature (buy via XP,
/// a "streak saved" notification trigger) that no client UI ever surfaced.
class StreakFreezeBadge extends StatelessWidget {
  const StreakFreezeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final freezes = context.select<RoutineProvider, int>(
      (p) => p.streakFreezes,
    );

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const StreakFreezeSheet(),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: OrbitTokens.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: OrbitTokens.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.ac_unit_rounded, color: OrbitTokens.teal, size: 13),
            const SizedBox(width: 4),
            Text(
              '$freezes',
              style: const TextStyle(
                color: OrbitTokens.teal,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StreakFreezeSheet extends StatefulWidget {
  const StreakFreezeSheet({super.key});

  @override
  State<StreakFreezeSheet> createState() => _StreakFreezeSheetState();
}

class _StreakFreezeSheetState extends State<StreakFreezeSheet> {
  Future<void> _buy(BuildContext context) async {
    final provider = context.read<RoutineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final error = await provider.buyStreakFreeze();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ?? 'Streak freeze purchased — your next miss is covered.',
        ),
        backgroundColor: error != null
            ? Colors.redAccent
            : OrbitTokens.teal.withValues(alpha: 0.9),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        final canAfford = provider.xp >= RoutineProvider.streakFreezeCost;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            decoration: const BoxDecoration(
              color: OrbitTokens.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: OrbitTokens.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.ac_unit_rounded,
                        color: OrbitTokens.teal,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Streak Freeze',
                            style: TextStyle(
                              color: OrbitTokens.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'You have ${provider.streakFreezes}',
                            style: const TextStyle(
                              color: OrbitTokens.inkDim,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Miss a day and one freeze absorbs it automatically — your '
                  'streak survives instead of resetting to zero.',
                  style: TextStyle(
                    color: OrbitTokens.inkDim,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: provider.isBuyingFreeze || !canAfford
                      ? null
                      : () => _buy(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: canAfford ? OrbitTokens.signal : null,
                      color: canAfford ? null : OrbitTokens.surface2,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Center(
                      child: provider.isBuyingFreeze
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: OrbitTokens.ground,
                              ),
                            )
                          : Text(
                              'Buy for ${RoutineProvider.streakFreezeCost} XP',
                              style: TextStyle(
                                color: canAfford
                                    ? OrbitTokens.ground
                                    : OrbitTokens.inkFaint,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'You have ${provider.xp} XP · earn 10 per habit',
                    style: const TextStyle(
                      color: OrbitTokens.inkFaint,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
