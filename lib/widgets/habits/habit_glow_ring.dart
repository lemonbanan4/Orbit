import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../../providers/atmosphere_provider.dart';
import '../stardust_burst.dart';

class HabitGlowRing extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final AnimationController? pulseController;

  const HabitGlowRing(
      {super.key,
      required this.progress,
      required this.isCompleted,
      this.pulseController});

  @override
  State<HabitGlowRing> createState() => _HabitGlowRingState();
}

class _HabitGlowRingState extends State<HabitGlowRing> {
  late ConfettiController _burstController;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _burstController = ConfettiController(duration: const Duration(seconds: 1));
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _burstController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get current Atmosphere to drive dynamic colors
    final atmosphere = context.watch<AtmosphereProvider>();

    // Construct the main progress ring
    Widget ring = SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        value: widget.isCompleted ? 1.0 : widget.progress,
        backgroundColor: Colors.white10,
        color: widget.isCompleted
            ? atmosphere.accentColor
            : atmosphere.primaryGlow,
        strokeWidth: 3,
      ),
    );

    // Add a continuous subtle pulse if completed
    if (widget.isCompleted) {
      ring = ring
          .animate(
            controller: widget.pulseController,
            autoPlay: widget.pulseController == null,
            onPlay: widget.pulseController == null
                ? (c) => c.repeat(reverse: true)
                : null,
          )
          .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.08, 1.08),
              duration: 1.5.seconds);
    }

    // Determine time of day to swap particle shapes!
    final hour = DateTime.now().hour;
    final isNight = hour >= 18 || hour < 5;

    return StardustBurst(
      controller: _burstController,
      numberOfParticles: 40, // More stardust!
      maxBlastForce: 30, // Faster explosion!
      createParticlePath:
          isNight ? StardustBurst.drawMoon : StardustBurst.drawStar,
      colors: [
        atmosphere.primaryGlow,
        atmosphere.accentColor,
        Colors.white,
      ],
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Glow Aura (Only shows when nearly done or completed)
          if (widget.progress > 0.8 || widget.isCompleted)
            GestureDetector(
              onTap: () async {
                // 1. Added 'async'
                if (widget.isCompleted) {
                  HapticFeedback.heavyImpact();
                  // 2. Use your existing _burstController here,
                  // don't create a new ConfettiController() on every tap!
                  _burstController.play();

                  // Play an additional sound effect when the burst happens
                  _audioPlayer.play(AssetSource('audio/success_chime.mp3'));
                }

                // 3. Proper await for Vibration
                if (await Vibration.hasVibrator() ?? false) {
                  Vibration.vibrate(pattern: [0, 10, 5, 10]);
                }

                if (!mounted) return;

                // Update the Atmosphere
                context.read<AtmosphereProvider>().setAura(OrbitAura.nova);
              },
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // Match aura with the Atmosphere
                      color: (widget.isCompleted
                              ? atmosphere.accentColor
                              : atmosphere.primaryGlow)
                          .withValues(alpha: 0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              )
                  .animate(
                    controller: widget.pulseController,
                    autoPlay: widget.pulseController == null,
                    onPlay: widget.pulseController == null
                        ? (c) => c.repeat(reverse: true)
                        : null,
                  )
                  .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.2, 1.2),
                      duration:
                          1.5.seconds), // Sync duration with central ticker
            ),

          ring, // Our dynamically styled and pulsing ring

          if (widget.isCompleted)
            Icon(Icons.check, color: atmosphere.accentColor, size: 20)
                .animate()
                .scale(duration: 200.ms, curve: Curves.bounceOut),
        ],
      ),
    );
  }
}
