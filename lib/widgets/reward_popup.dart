// lib/widgets/reward_popup.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'common/premium_glass_card.dart';

class RewardPopup {
  // --- LEVELING SYSTEM MATH (Preserved from your original logic) ---
  static int getLevel(int totalXp) {
    int level = 1;
    int xpNeeded = 100;
    int xp = totalXp;
    while (xp >= xpNeeded) {
      xp -= xpNeeded;
      level++;
      xpNeeded += 50;
    }
    return level;
  }

  static double getLevelProgress(int totalXp) {
    int xpNeeded = 100;
    int xp = totalXp;
    while (xp >= xpNeeded) {
      xp -= xpNeeded;
      xpNeeded += 50;
    }
    return xp / xpNeeded;
  }

  static void show(
    BuildContext context, {
    required String title,
    required int xpEarned,
    int? currentTotalXp,
    String audioPath = 'audio/success_chime.mp3',
  }) {
    HapticFeedback.heavyImpact();

    bool isLevelUp = false;
    if (currentTotalXp != null) {
      final oldLevel = getLevel(currentTotalXp - xpEarned);
      final newLevel = getLevel(currentTotalXp);
      if (newLevel > oldLevel) {
        isLevelUp = true;
        title = "LEVEL UP!";
        audioPath = 'audio/milestone_unlock.mp3';
      }
    }

    // Play Audio Chimes safely
    try {
      final player = AudioPlayer();
      player.play(AssetSource(audioPath));
    } catch (e) {
      debugPrint('Error playing reward sound: $e');
    }

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox(),
      // Inside reward_popup.dart -> showGeneralDialog -> transitionBuilder:
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 12 * animation.value,
            sigmaY: 12 * animation.value,
          ),
          child: Opacity(
            opacity: animation.value.clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.center, // FIXED: Centered on screen viewport
              child: Padding(
                padding: const EdgeInsets.all(
                  24.0,
                ), // Clean uniform surrounding padding
                child: Material(
                  color: Colors.transparent,
                  child: PremiumGlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min, // Hugs content perfectly in center
                      children: [
                        Row(
                          children: [
                            Icon(
                                  isLevelUp
                                      ? Icons.keyboard_double_arrow_up_rounded
                                      : Icons.auto_awesome,
                                  color: isLevelUp
                                      ? const Color(0xFF00E5FF)
                                      : Colors.amber,
                                  size: 32,
                                )
                                .animate(onPlay: (c) => c.repeat())
                                .shimmer(duration: 1.5.seconds)
                                .scaleXY(
                                  begin: 0.9,
                                  end: 1.1,
                                  duration: 800.ms,
                                  curve: Curves.easeInOut,
                                ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    title.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "+$xpEarned MATRIX ENERGY ALIGNED",
                                    style: TextStyle(
                                      color: isLevelUp
                                          ? Colors.amberAccent
                                          : const Color(0xFF00E5FF),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (currentTotalXp != null) ...[
                          const SizedBox(height: 14),
                          Divider(color: Colors.white.withValues(alpha: 0.08)),
                          const SizedBox(height: 8),
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Level ${getLevel(currentTotalXp)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${(getLevelProgress(currentTotalXp) * 100).toInt()}% Alignment',
                                    style: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: getLevelProgress(currentTotalXp),
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.05,
                                  ),
                                  color: const Color(0xFF00E5FF),
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              "CONTINUE",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
