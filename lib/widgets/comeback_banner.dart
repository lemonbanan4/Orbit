import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/routine_provider.dart';
import '../theme/orbit_tokens.dart';

/// Forgiveness & recovery (v1.2). When a streak breaks while the user is away,
/// we greet them with this warm, guilt-free comeback prompt instead of a
/// silent zero -- naming the streak they lost and framing it as a relaunch,
/// not a failure. It disappears the moment they rebuild (markRoutineComplete)
/// or tap the close button (dismissComeback). Purely a view.
class ComebackBanner extends StatelessWidget {
  const ComebackBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoutineProvider>();
    if (!provider.hasPendingComeback) return const SizedBox.shrink();

    final lost = provider.lostStreak;
    final headline = lost > 0
        ? 'Welcome back, Commander 🚀'
        : 'Welcome back 🚀';
    final body = lost > 0
        ? 'Your $lost-day streak paused while you were away — no guilt, every '
            'legend has a comeback. Complete a habit to relight it.'
        : 'Life happens. Pick one small habit and start a fresh orbit today.';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            OrbitTokens.gold.withValues(alpha: 0.16),
            OrbitTokens.violet.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OrbitTokens.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('🔥', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: const TextStyle(
                    color: OrbitTokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: OrbitTokens.inkDim,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              context.read<RoutineProvider>().dismissComeback();
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 6, top: 2),
              child: Icon(
                Icons.close_rounded,
                color: OrbitTokens.inkFaint,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
