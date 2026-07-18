import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/ai_fairy_provider.dart';
import '../../providers/routine_provider.dart';
import '../../providers/telemetry_provider.dart';
import '../../providers/atmosphere_provider.dart';
import 'premium_glass_card.dart';
import '../../../services/voice_service.dart';
import '../reward_popup.dart';

class AIFairyOverlay extends StatelessWidget {
  final double bottomPadding;

  const AIFairyOverlay({super.key, this.bottomPadding = 120.0});

  @override
  Widget build(BuildContext context) {
    return Consumer<AIFairyProvider>(
      builder: (context, fairy, child) {
        if (!fairy.isCheering) return const SizedBox.shrink();

        // Cosmica "casts" an aura on every habit completion (see
        // AtmosphereProvider.auraForHabitCompletion) — reflect it in her
        // own glow here, the moment it's most visible.
        final atmosphere = context.watch<AtmosphereProvider>();
        final Color calmAccent = atmosphere.primaryGlow;

        // Dynamic Avatar that reacts to Cosmica's internal state
        Widget avatar = Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: fairy.isThinking
                    ? const Color(0xFFBC13FE).withValues(
                        alpha: 0.8,
                      ) // Intense purple glow when listening/thinking
                    : calmAccent.withValues(
                        alpha: 0.5,
                      ), // Calm brand-accent glow otherwise
                blurRadius: fairy.isThinking ? 30 : 20,
                spreadRadius: fairy.isThinking ? 5 : 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/fairy_avatar.png',
            width: 52,
            height: 52,
          ),
        );

        // Conditionally apply fast rapid vibrating/shimmer vs slow breathing
        avatar = fairy.isThinking
            ? avatar
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.95, end: 1.05, duration: 300.ms)
                  .shimmer(color: Colors.white54, duration: 600.ms)
            : avatar
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.9, end: 1.1, duration: 5.seconds);

        return Padding(
          padding: EdgeInsets.only(
            top: 24.0,
            bottom: bottomPadding,
            left: 24.0,
            right: 24.0,
          ),
          child:
              PremiumGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- AI FAIRY AVATAR ---
                        GestureDetector(
                          onTap: () {
                            // Make the fairy speak her current message when tapped!
                            VoiceService.speak(fairy.currentMessage);

                            final routineProvider = context
                                .read<RoutineProvider>();
                            final telemetryProvider = context
                                .read<TelemetryProvider>();
                            if (routineProvider.incrementFairyTaps()) {
                              RewardPopup.show(
                                context,
                                title: "Cosmica's Secret Badge Unlocked!",
                                xpEarned: 500,
                                currentTotalXp: telemetryProvider.globalXp,
                              );
                            }
                          },
                          child: avatar,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cosmica',
                                style: TextStyle(
                                  color: calmAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (fairy.isThinking)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: calmAccent,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  fairy.currentMessage,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              if (!fairy.isThinking &&
                                  fairy.suggestedReplies.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: fairy.suggestedReplies.map((reply) {
                                    return ActionChip(
                                      label: Text(
                                        reply,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: const Color(
                                        0xFF1A1F36,
                                      ).withValues(alpha: 0.8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                      side: BorderSide.none,
                                      onPressed: () => fairy.dismissFairy(),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                          ),
                          onPressed: () => fairy.dismissFairy(),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fade(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
        );
      },
    );
  }
}
