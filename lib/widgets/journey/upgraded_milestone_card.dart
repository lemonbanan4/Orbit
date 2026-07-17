import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../screens/journey/journey_screen.dart'; // Adjust exact path maps if needed
import '../../theme/orbit_tokens.dart';
import '../../screens/features/nebula_forge_screen.dart'; // Adjust exact path maps if needed

class UpgradedMilestoneCard extends StatelessWidget {
  final int index;
  final JourneyMilestone milestone;
  final bool isUnlocked;

  /// The first not-yet-unlocked milestone: teal halo + days progress,
  /// per the pitch's three-state timeline (done / current / locked).
  final bool isCurrent;
  final int currentStreak;
  final bool isLast;

  const UpgradedMilestoneCard({
    super.key,
    required this.index,
    required this.milestone,
    required this.isUnlocked,
    this.isCurrent = false,
    this.currentStreak = 0,
    required this.isLast,
  });

  void _handleNodeInteractions(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (!isUnlocked) {
      _showAiGatekeeperPopup(context);
    } else {
      _showMilestoneCompletionPopup(context);
    }
  }

  void _showAiGatekeeperPopup(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Gatekeeper",
      transitionDuration: 400.ms,
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: anim1.value,
          child: Opacity(
            opacity: anim1.value,
            child: AlertDialog(
              backgroundColor: OrbitTokens.surface.withValues(alpha: 0.95),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Colors.white10),
              ),
              title: const Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: OrbitTokens.violet),
                  SizedBox(width: 12),
                  Text(
                    "CELESTIAL BARRIER",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.transparent,
                    backgroundImage: AssetImage(
                      'assets/images/fairy_avatar.png',
                    ),
                  ).animate().shake(),
                  const SizedBox(height: 16),
                  Text(
                    "\"Hold, Voyager. To cross into the atmospheric field of ${milestone.title}, your energy matrix requires a consecutive ${milestone.requiredStreak}-day streak alignment.\"",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.4,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "RETURN TO ALIGNMENT",
                    style: TextStyle(color: OrbitTokens.teal),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMilestoneCompletionPopup(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NebulaForgeScreen(
          sourcePhase: milestone.title, // Sends the specific phase title down
        ),
      ),
    );
  }

  // lib/widgets/journey/upgraded_milestone_card.dart

  // lib/widgets/journey/upgraded_milestone_card.dart

  @override
  Widget build(BuildContext context) {
    const Color pathActiveGlow = OrbitTokens.teal;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // NODE CONNECTOR STREAM (Left Panel)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _handleNodeInteractions(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Pitch states: earned = gold, current = teal ring
                      // on dark, locked = quiet surface.
                      color: isUnlocked
                          ? OrbitTokens.gold
                          : OrbitTokens.surface2,
                      border: Border.all(
                        color: isUnlocked
                            ? Colors.white
                            : isCurrent
                                ? pathActiveGlow
                                : Colors.white10,
                        width: isCurrent ? 2 : 1.5,
                      ),
                      boxShadow: isUnlocked
                          ? [
                              BoxShadow(
                                color:
                                    OrbitTokens.gold.withValues(alpha: 0.55),
                                blurRadius: 14,
                                spreadRadius: 3,
                              ),
                            ]
                          : isCurrent
                              ? [
                                  BoxShadow(
                                    color: pathActiveGlow.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 12,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : [],
                    ),
                    child: isUnlocked
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.black,
                          )
                        : isCurrent
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: pathActiveGlow,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.lock_rounded,
                                size: 12,
                                color: Colors.white30,
                              ),
                  ),
                ),
                // THE CONNECTING VECTOR LINE + COMET EFFECT
                if (!isLast)
                  Expanded(
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isUnlocked
                                  ? [
                                      OrbitTokens.gold,
                                      OrbitTokens.gold.withValues(alpha: 0.2),
                                    ]
                                  : [Colors.white10, Colors.transparent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Loop a tiny glowing star along the track rail line vectors
                        if (isUnlocked)
                          const Icon(Icons.circle, color: Colors.white, size: 6)
                              .animate(onPlay: (c) => c.repeat())
                              .moveY(
                                begin: 0,
                                end: 100,
                                duration: 2.seconds,
                                curve: Curves.easeInCubic,
                              )
                              .fade(begin: 0.0, end: 1.0, duration: 300.ms)
                              .then(delay: 1.4.seconds)
                              .fade(begin: 1.0, end: 0.0, duration: 300.ms),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // FULL INTERACTIVE 3D GLASS CARD (Right Panel)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: GestureDetector(
                onTap: () => _handleNodeInteractions(
                  context,
                ), // Entire card is now completely clickable!
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isUnlocked
                              ? [
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.white.withValues(alpha: 0.02),
                                ]
                              : [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.black.withValues(alpha: 0.2),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isUnlocked
                              ? Colors.white.withValues(alpha: 0.18)
                              : isCurrent
                                  ? OrbitTokens.teal.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.04),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                milestone.phase,
                                style: TextStyle(
                                  color: isUnlocked
                                      ? OrbitTokens.gold
                                      : isCurrent
                                          ? OrbitTokens.teal
                                          : Colors.white30,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              if (isUnlocked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: OrbitTokens.gold.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    "UNLOCKED",
                                    style: TextStyle(
                                      color: OrbitTokens.gold,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                )
                              else if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: OrbitTokens.teal.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "$currentStreak OF ${milestone.requiredStreak} DAYS",
                                    style: const TextStyle(
                                      color: OrbitTokens.teal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            milestone.title,
                            style: TextStyle(
                              color: isUnlocked ? Colors.white : Colors.white38,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            milestone.subtitle,
                            style: TextStyle(
                              color: isUnlocked
                                  ? Colors.white70
                                  : Colors.white30,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Divider(color: Colors.white.withValues(alpha: 0.05)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                milestone.rewardIcon,
                                size: 14,
                                color: isUnlocked
                                    ? OrbitTokens.gold
                                    : Colors.white24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isUnlocked
                                      ? "Unlocked: ${milestone.rewardName}"
                                      : "Locks: ${milestone.rewardName}",
                                  style: TextStyle(
                                    color: isUnlocked
                                        ? Colors.white60
                                        : Colors.white24,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
