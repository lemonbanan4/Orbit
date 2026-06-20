import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../habits/habit_glow_ring.dart';
import 'premium_glass_card.dart';

class HabitGlassCard extends StatelessWidget {
  final String title, time;
  final IconData icon;
  final Color accentColor;
  final bool isCompleted;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final AnimationController? pulseController;

  const HabitGlassCard({
    super.key,
    required this.title,
    required this.time,
    required this.icon,
    required this.accentColor,
    required this.isCompleted,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onSurface;

    Widget card = AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isCompleted ? 0.5 : 1.0,
      child: PremiumGlassCard(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.5),
                    accentColor.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: textColor.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                      if (!isCompleted) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.hourglass_bottom_rounded,
                            size: 14,
                            color: accentColor.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text('Hold to Focus',
                            style: TextStyle(
                                color: accentColor.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            HabitGlowRing(
              progress: isCompleted ? 1.0 : 0.0,
              isCompleted: isCompleted,
              pulseController: pulseController,
            ),
          ],
        ),
      ),
    );

    // Pulse the entire card in sync with the glow ring!
    if (isCompleted) {
      card = card
          .animate(
            controller: pulseController,
            autoPlay: pulseController == null,
            onPlay:
                pulseController == null ? (c) => c.repeat(reverse: true) : null,
          )
          .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.02, 1.02), // A subtle, synchronized throbbing
              duration: 1.5.seconds);
    }

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: card,
    );
  }
}
