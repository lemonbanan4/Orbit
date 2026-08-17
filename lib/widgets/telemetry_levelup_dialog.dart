// lib/widgets/telemetry_levelup_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../screens/paywall/paywall_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/routine_provider.dart';
import '../../data/cosmic_ranks.dart';

class TelemetryLevelUpDialog {
  static void show(BuildContext context, int newLevel, {String? habitTitle}) {
    HapticFeedback.heavyImpact();

    final bool isPro = context.read<AppAuthProvider>().isPro ?? false;
    final bool triggerProUpsell =
        !isPro &&
        (newLevel % 2 == 0); // Upsell on alternating levels for free users

    // A Cosmic Rank's minLevel is the exact level a user just landed on the
    // moment they cross into it (ranks are contiguous and Level only ever
    // increments by 1), so this is true only on the specific level-up that
    // unlocked a new rank tier, not every level-up.
    final rank = cosmicRankForLevel(newLevel);
    final bool isRankUp = rank.minLevel == newLevel;

    // Was previously just a number tick with nothing to show for it --
    // grant a small spendable-XP bonus (bigger on a rank crossing) so
    // leveling up funds the next streak freeze / Nebula theme unlock.
    context.read<RoutineProvider>().grantLevelUpBonus(
          newLevel,
          isRankUp: isRankUp,
        );
    final int bonusXp = isRankUp ? 50 : 15;

    final String dynamicMessage = habitTitle != null
        ? "\"Incredible, star-seeker! Completing '$habitTitle' has pushed your steady orbit through to Rank $newLevel. The cosmic dust expands around your discipline inside the Nebula Forge!\""
        : "\"Incredible, star-seeker! Your steady orbit has broken through to Rank $newLevel. The cosmic dust expands around your discipline inside the Nebula Forge!\"";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          backgroundColor: const Color(0xFF060216).withValues(alpha: 0.98),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
            side: BorderSide(color: Color(0xFF00E5FF), width: 1.2),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Supercharged AI Fairy Avatar Module for Level Ups
              Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Color(0xFFFFD700), // Cosmic Gold
                          Color(0xFFBC13FE), // Deep Purple
                          Color(0xFF00E5FF), // Cyan Core
                          Color(0xFFFFD700), // Cosmic Gold
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: const Color(0xFFBC13FE).withValues(alpha: 0.3),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 38,
                      backgroundColor: Color(0xFF0A051D),
                      backgroundImage: AssetImage(
                        'assets/images/fairy_avatar.png',
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: -8,
                    end: 8,
                    duration: 2.seconds,
                    curve: Curves.easeInOut,
                  )
                  .scaleXY(begin: 0.95, end: 1.05, duration: 1.2.seconds)
                  .shimmer(color: Colors.white, duration: 1500.ms),
              const SizedBox(height: 16),
              Text(
                isRankUp ? "NEW COSMIC RANK" : "ORBIT LEVEL ALIGNMENT",
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isRankUp
                    ? "${rank.title} · Level $newLevel"
                    : "${rank.title} · Level $newLevel Unlocked",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "+$bonusXp XP earned",
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // AI Dialogue Box Overlay
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  dynamicMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                    fontFamily: 'Serif',
                  ),
                ),
              ),

              if (triggerProUpsell) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaywallScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      "UNLOCK ADVANCED PRO MATRIX",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  triggerProUpsell
                      ? "CONTINUE AS FREE VOYAGER"
                      : "SECURE MY ORBIT",
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}
