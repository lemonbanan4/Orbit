import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';

class ShareMilestoneButton extends StatelessWidget {
  final String milestoneTitle;
  final int streakCount;

  const ShareMilestoneButton({
    super.key,
    required this.milestoneTitle,
    required this.streakCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        final String shareText =
            "🚀 I just completed '$milestoneTitle' and hit a $streakCount day streak in Orbit! Join me in building better habits.";
        Share.share(shareText);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.ios_share_rounded, color: Color(0xFF00E5FF)),
                SizedBox(width: 12),
                Text(
                  "Share Milestone",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack).fade();
  }
}
