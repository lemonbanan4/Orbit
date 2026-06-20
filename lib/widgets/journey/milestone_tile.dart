import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:provider/provider.dart';
import '../../providers/ai_fairy_provider.dart';
import '../../providers/atmosphere_provider.dart';
import '../../providers/routine_provider.dart';
import '../stardust_burst.dart';
import '../ai_fairy_bubble.dart';
import '../../services/ai_fairy_service.dart';

class MilestoneTile extends StatefulWidget {
  final int index;
  final bool isSideQuest;
  final bool isRareReward;
  final bool isUnlocked;

  const MilestoneTile(
      {super.key,
      required this.index,
      this.isSideQuest = false,
      this.isRareReward = false,
      this.isUnlocked = false});

  @override
  State<MilestoneTile> createState() => _MilestoneTileState();
}

class _MilestoneTileState extends State<MilestoneTile>
    with TickerProviderStateMixin {
  late ConfettiController _burstController;
  bool _isUnlocking = false;
  bool _isUnlocked = false;
  late AudioPlayer _audioPlayer;
  late AnimationController _wiggleController;
  late AnimationController _rejectParticleController;
  late ConfettiController _miniBurstController;

  @override
  void initState() {
    super.initState();
    _burstController = ConfettiController(duration: const Duration(seconds: 1));
    _audioPlayer = AudioPlayer();
    _wiggleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _rejectParticleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _miniBurstController =
        ConfettiController(duration: const Duration(milliseconds: 100));
  }

  @override
  void dispose() {
    _burstController.dispose();
    _audioPlayer.dispose();
    _wiggleController.dispose();
    _rejectParticleController.dispose();
    _miniBurstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();

    // Combine hardcoded preview, cloud state, and local unlock animation state
    bool isCompleted = widget.index < 3 ||
        routineProvider.unlockedMilestones.contains(widget.index) ||
        _isUnlocked ||
        widget.isUnlocked; // Use the passed-in parameter!

    final atmosphere = context.watch<AtmosphereProvider>();

    // Dynamic streak-based particle calculations!
    final int streak = routineProvider.currentStreak;
    final int cappedStreak =
        streak > 100 ? 100 : streak; // Cap at 100 days for logic

    // Particle grows up to 32px, speed decreases duration from 1500ms down to 600ms
    final double particleLength = 12.0 + (cappedStreak * 0.2);
    final int particleDurationMs = 1500 - (cappedStreak * 9);
    final int fadeOutDelayMs = particleDurationMs - 200;

    // Build the glass card element so we can wrap it in dynamic animations
    Widget glassCard = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isCompleted
                  ? Colors.amber.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              // Milestone Icon
              StardustBurst(
                controller: _burstController,
                // Dynamically match the track gradient!
                colors: List.generate(
                  5,
                  (i) => Color.lerp(
                      atmosphere.primaryGlow, atmosphere.accentColor, i / 4)!,
                )..add(Colors.white),
                child: Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.black26,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: isCompleted
                        ? Image.asset(
                            'assets/icons/milestone_${widget.index}.png',
                            key: const ValueKey('icon'),
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.star,
                                    key: ValueKey('star'),
                                    color: Colors.white24),
                          )
                        : const Icon(Icons.lock_rounded,
                            key: ValueKey('lock'), color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Milestone Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Phase ${widget.index + 1}",
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        isCompleted ? "Stellar Growth" : "Future Path",
                        key: ValueKey(isCompleted),
                        style: TextStyle(
                          color: isCompleted ? Colors.white : Colors.white38,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- THE PROGRESS BUBBLE ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  key: ValueKey(isCompleted),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.greenAccent.withValues(alpha: 0.2)
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isCompleted ? "DONE" : "${widget.index + 1}/5",
                    style: TextStyle(
                      color: isCompleted ? Colors.greenAccent : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Shiver effect while unlocking, followed by an expansion bounce
    if (_isUnlocking) {
      glassCard = glassCard
          .animate()
          .shake(duration: 600.ms, hz: 4)
          .shimmer(duration: 600.ms, color: Colors.white24);
    } else if (_isUnlocked) {
      glassCard = glassCard.animate().scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          curve: Curves.easeOutBack);
    }

    // Add wiggle for locked tap
    glassCard = glassCard
        .animate(controller: _wiggleController, autoPlay: false)
        .shakeX(amount: 5, hz: 4, duration: 300.ms);

    // Add glowing aura for rare side-quest rewards
    if (widget.isSideQuest && widget.isRareReward) {
      glassCard =
          glassCard.animate(onPlay: (c) => c.repeat(reverse: true)).boxShadow(
                begin: const BoxShadow(color: Colors.transparent),
                end: BoxShadow(
                  color: atmosphere.primaryGlow.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
                duration: 2.seconds,
              );
    }

    Widget resultTile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(children: [
        // --- THE DASHED TRACK ---
        Column(
          children: [
            SizedBox(
              width: 3,
              height: 120,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      15,
                      (i) => Stack(
                        children: [
                          // The Unlit Dash
                          Container(
                            width: 3,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Colors.white10,
                            ),
                          ),
                          // The Sequentially Lit Dash
                          Container(
                            width: 3,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: Color.lerp(atmosphere.primaryGlow,
                                  atmosphere.accentColor, i / 15),
                            ),
                          )
                              // 1. The Flowing Animation (Travels consistently downwards)
                              .animate(
                                key: ValueKey('pulse_${isCompleted}_$i'),
                                onPlay: (c) {
                                  if (isCompleted) c.loop();
                                }, // Removed reverse to snap and flow
                              )
                              .fade(
                                  begin: 0.2,
                                  end: 1.0,
                                  duration: 600.ms,
                                  delay: (i * 40).ms)
                              // 2. The Sequential Reveal
                              .animate(target: isCompleted ? 1 : 0)
                              .fade(duration: 200.ms, delay: (i * 30).ms),
                        ],
                      ),
                    ),
                  ),
                  // The traveling glowing particle!
                  if (isCompleted)
                    Positioned(
                      top: 0,
                      child: Container(
                        width: 5,
                        height: particleLength,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: atmosphere.primaryGlow,
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.loop())
                          .moveY(
                              begin: -10,
                              end: 120,
                              duration: particleDurationMs.ms)
                          .fade(begin: 0, end: 1, duration: 200.ms)
                          .fadeOut(delay: fadeOutDelayMs.ms, duration: 200.ms)
                          .callback(
                            delay: fadeOutDelayMs.ms,
                            callback: (_) => _miniBurstController.play(),
                          ),
                    ),

                  // The mini explosion at the bottom!
                  if (isCompleted)
                    Positioned(
                      bottom: -5,
                      child: StardustBurst(
                        controller: _miniBurstController,
                        numberOfParticles: 8,
                        maxBlastForce: 10,
                        minBlastForce: 2,
                        colors: [
                          atmosphere.primaryGlow,
                          atmosphere.accentColor,
                          Colors.white
                        ],
                        child: const SizedBox(width: 5, height: 5),
                      ),
                    ),

                  // The rejection upward particle!
                  Positioned(
                    top: 0,
                    child: Container(
                      width: 5,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.redAccent,
                              blurRadius: 8,
                              spreadRadius: 2),
                        ],
                      ),
                    )
                        .animate(
                            controller: _rejectParticleController,
                            autoPlay: false)
                        .fade(begin: 0, end: 1, duration: 100.ms)
                        // Shoots up fast and slows down at the top
                        .moveY(
                            begin: 120,
                            end: -10,
                            duration: 600.ms,
                            curve: Curves.easeOutExpo)
                        .fadeOut(delay: 500.ms, duration: 100.ms),
                  ),
                ],
              ),
            ),
          ],
        ),

        // --- HORIZONTAL SIDE-QUEST BRANCH ---
        if (widget.isSideQuest) ...[
          const SizedBox(width: 8),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Row(
                children: List.generate(
                  4,
                  (i) => Container(
                    width: 6,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isCompleted
                          ? Color.lerp(atmosphere.primaryGlow,
                              atmosphere.accentColor, i / 4)
                          : Colors.white10,
                    ),
                  )
                      .animate(
                        key: ValueKey('h_pulse_${isCompleted}_$i'),
                        onPlay: (c) {
                          if (isCompleted) c.loop();
                        },
                      )
                      .fade(
                          begin: 0.2,
                          end: 1.0,
                          duration: 600.ms,
                          delay: (i * 40).ms)
                      .animate(target: isCompleted ? 1 : 0)
                      .fade(duration: 200.ms, delay: (i * 30).ms),
                ),
              ),

              // The traveling horizontal glowing particle!
              if (isCompleted)
                Positioned(
                  left: 0,
                  child: Container(
                    width: particleLength, // Elongated horizontally
                    height: 5, // Thin vertically
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                            color: atmosphere.primaryGlow,
                            blurRadius: 8,
                            spreadRadius: 2),
                      ],
                    ),
                  )
                      .animate(onPlay: (c) => c.loop())
                      .moveX(
                          begin: -10, end: 40, duration: particleDurationMs.ms)
                      .fade(begin: 0, end: 1, duration: 200.ms)
                      .fadeOut(delay: fadeOutDelayMs.ms, duration: 200.ms),
                ),

              // AI Fairy tip for locked side-quests
              if (!isCompleted && !_isUnlocking)
                Positioned(
                  top: 15,
                  left: -12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.purpleAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome,
                            color: atmosphere.accentColor, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          "Bonus Loot",
                          style: TextStyle(
                            color: atmosphere.accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(
                          begin: 0,
                          end: -3,
                          duration: 1.seconds) // Bouncing float effect
                      .fade(duration: 800.ms),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ] else
          const SizedBox(width: 20),

        // --- THE GLASS CARD ---
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_isUnlocking) return;

              final atmosphereProvider = context.read<AtmosphereProvider>();

              if (isCompleted) {
                // If it's already unlocked, just show the dialog so they can share!
                // This prevents them from spamming the sound effect or re-triggering the unlock.
                HapticFeedback.lightImpact();
                _showMilestoneDialog(atmosphereProvider);
                return;
              }

              // Check if it's ahead of their progress
              int maxUnlocked =
                  2; // Indices 0, 1, 2 are auto-completed by default
              if (routineProvider.unlockedMilestones.isNotEmpty) {
                final cloudMax = routineProvider.unlockedMilestones
                    .reduce((a, b) => a > b ? a : b);
                if (cloudMax > maxUnlocked) maxUnlocked = cloudMax;
              }

              if (widget.index > maxUnlocked + 1) {
                _wiggleController.forward(from: 0.0);
                _rejectParticleController.forward(
                    from: 0.0); // Shoot the red particle UP!
                HapticFeedback.lightImpact();
                if (context.read<RoutineProvider>().soundsEnabled) {
                  _audioPlayer.play(AssetSource('audio/locked.mp3'));
                }

                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        const Text("You must unlock previous phases first"),
                    backgroundColor: atmosphereProvider.primaryGlow,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              setState(() {
                _isUnlocking = true;
              });
              HapticFeedback.lightImpact(); // Click to start unlocking!

              // Delay the actual reveal while it shivers
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) {
                  setState(() {
                    _isUnlocking = false;
                    _isUnlocked = true;
                  });
                  _burstController.play(); // BOOM!
                  HapticFeedback.heavyImpact();
                  Vibration.vibrate(duration: 50, amplitude: 128);

                  atmosphereProvider.setAura(
                      widget.index > 5 ? OrbitAura.nova : OrbitAura.dawn);

                  // Save to the cloud sequence!
                  context.read<RoutineProvider>().unlockMilestone(widget.index);

                  // Play custom milestone sound!
                  if (context.read<RoutineProvider>().soundsEnabled) {
                    _audioPlayer
                        .play(AssetSource('audio/milestone_unlock.mp3'));
                  }

                  try {
                    context.read<AIFairyProvider>().cheerForHabit(
                          "Milestone ${widget.index + 1}",
                          7,
                          playSound:
                              context.read<RoutineProvider>().soundsEnabled,
                        );
                  } catch (_) {}

                  // Show celebratory popup
                  _showMilestoneDialog(atmosphereProvider);
                }
              });
            },
            child: glassCard,
          ),
        ),
      ]),
    );

    if (widget.isRareReward) {
      resultTile = resultTile
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
              begin: -5, end: 5, duration: 2.seconds, curve: Curves.easeInOut);
    }

    return resultTile;
  }

  Future<Uint8List?> _generateWatermarkedImage() async {
    if (!mounted) return null;

    // Cache provider data BEFORE any async gaps to avoid BuildContext lint warnings!
    final atmosphere = context.read<AtmosphereProvider>();
    final streak = context.read<RoutineProvider>().currentStreak;
    final avatarName = context.read<RoutineProvider>().selectedAvatar;

    try {
      // 1. Load the image directly from the asset bundle
      final byteData =
          await rootBundle.load('assets/icons/milestone_${widget.index}.png');
      final codec = await instantiateImageCodec(byteData.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // 1.25 Load App Logo for QR Code
      dynamic qrLogoImage;
      try {
        final logoByteData = await rootBundle.load('assets/icons/icon.png');
        final logoCodec =
            await instantiateImageCodec(logoByteData.buffer.asUint8List());
        final logoFrame = await logoCodec.getNextFrame();
        qrLogoImage = logoFrame.image;
      } catch (e) {
        // Fallback gracefully if logo is missing
      }

      // 1.5 Load Dynamic Background Image based on Chapter
      // Assuming 5 phases per chapter: Phase 1-5 = Chapter 1, Phase 6-10 = Chapter 2...
      final int chapter = (widget.index ~/ 5) + 1;
      bool hasBgImage = false;
      late final dynamic
          bgImage; // Use dynamic to avoid dart:ui Image collision
      try {
        final bgByteData = await rootBundle
            .load('assets/journeygen/chapter_${chapter}_bg.png');
        final bgCodec =
            await instantiateImageCodec(bgByteData.buffer.asUint8List());
        final bgFrame = await bgCodec.getNextFrame();
        bgImage = bgFrame.image;
        hasBgImage = true;
      } catch (e) {
        // Fallback to solid colors if chapter art isn't found
      }

      // 2. Create Canvas to draw the watermark
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);

      // --- 3. Draw Nebula Background ---
      final width = image.width.toDouble();
      final height = image.height.toDouble();
      final bgRect = Rect.fromLTWH(0, 0, width, height);

      if (hasBgImage) {
        paintImage(
          canvas: canvas,
          rect: bgRect,
          image: bgImage,
          fit: BoxFit.cover,
        );
      } else {
        // Base deep space color dynamically based on OrbitAura
        Color baseBgColor;
        switch (atmosphere.currentAura) {
          case OrbitAura.dawn:
            baseBgColor = const Color(0xFF001F3F);
            break;
          case OrbitAura.nova:
            baseBgColor = const Color(0xFF2A0800);
            break;
          case OrbitAura.deepNebula:
            baseBgColor = const Color(0xFF1A002A);
            break;
          case OrbitAura.voidSpace:
          default:
            baseBgColor = const Color(0xFF051024);
        }
        canvas.drawRect(bgRect, Paint()..color = baseBgColor);
      }

      // Primary nebula glow (dynamically matches Aura)
      final primaryGlow = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.5, -0.5),
          radius: 1.0,
          colors: [
            widget.isSideQuest
                ? Colors.amber.withValues(alpha: 0.4)
                : atmosphere.primaryGlow.withValues(alpha: 0.4),
            Colors.transparent,
          ],
        ).createShader(bgRect);
      canvas.drawRect(bgRect, primaryGlow);

      // Secondary nebula glow (dynamically matches Aura)
      final accentGlow = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.5, 0.5),
          radius: 0.8,
          colors: [
            widget.isSideQuest
                ? Colors.deepOrangeAccent.withValues(alpha: 0.3)
                : atmosphere.accentColor.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ).createShader(bgRect);
      canvas.drawRect(bgRect, accentGlow);

      // Physics-based Stardust system
      final random = math.Random(widget.index);
      List<_StardustParticle> particles = [];

      // Dynamically select particle colors based on the active Aura
      final List<Color> particleColors = [
        atmosphere.primaryGlow,
        atmosphere.accentColor,
        Colors.white,
        if (widget.isSideQuest) Colors.amber,
      ];

      // Spawn particles from the center with random velocities
      for (int i = 0; i < 80; i++) {
        particles.add(_StardustParticle(
          x: width / 2,
          y: height / 2,
          vx: (random.nextDouble() - 0.5) * 24,
          vy: (random.nextDouble() - 0.5) * 24,
          size: random.nextDouble() * 2.0 + 0.5,
          alpha: random.nextDouble() * 0.6 + 0.2,
          color: particleColors[random.nextInt(particleColors.length)],
        ));
      }

      // Simulate 40 frames of floating physics
      for (int frame = 0; frame < 40; frame++) {
        for (var p in particles) {
          p.x += p.vx;
          p.y += p.vy;
          // Friction to slow them down smoothly
          p.vx *= 0.92;
          p.vy *= 0.92;
          // Organic floating drift/noise
          p.vx += (random.nextDouble() - 0.5) * 1.5;
          p.vy += (random.nextDouble() - 0.5) * 1.5;
        }
      }

      // Draw the settled stardust particles
      for (var p in particles) {
        // Outer glow
        final starGlowPaint = Paint()
          ..color = p.color.withValues(alpha: p.alpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        canvas.drawCircle(Offset(p.x, p.y), p.size * 2.5, starGlowPaint);

        // Inner bright core (Mix the aura color with bright white!)
        final starCorePaint = Paint()
          ..color = Color.lerp(p.color, Colors.white, 0.5)!
              .withValues(alpha: (p.alpha + 0.4).clamp(0.0, 1.0));
        canvas.drawCircle(Offset(p.x, p.y), p.size * 0.5, starCorePaint);
      }

      // 4. Draw Original Image over the Nebula
      canvas.drawImage(image, Offset.zero, Paint());

      // 4.25 Add Subtle Vignette Effect (Darkens the edges)
      final vignettePaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.8),
          ],
          stops: const [0.4, 1.0],
        ).createShader(bgRect);
      canvas.drawRect(bgRect, vignettePaint);

      // 4.5 Draw Intricate Border Frame
      // Setup Glow Paint
      final glowPaint = Paint()
        ..color = atmosphere.primaryGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      final borderPaint = Paint()
        ..color = atmosphere.primaryGlow.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0;

      // Draw Glowing Outer border
      final outerRect = Rect.fromLTWH(15, 15, width - 30, height - 30);
      canvas.drawRect(outerRect, glowPaint);
      canvas.drawRect(outerRect, borderPaint);

      // Inner thin border
      borderPaint.color = Colors.white.withValues(alpha: 0.5);
      borderPaint.strokeWidth = 2.0;
      canvas.drawRect(
          Rect.fromLTWH(25, 25, width - 50, height - 50), borderPaint);

      // Corner accents with glow
      final cornerGlowPaint = Paint()
        ..color = atmosphere.accentColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      final cornerPaint = Paint()..color = atmosphere.accentColor;

      const double cornerSize = 12.0;
      final corners = [
        const Rect.fromLTWH(10, 10, cornerSize, cornerSize),
        Rect.fromLTWH(width - 10 - cornerSize, 10, cornerSize, cornerSize),
        Rect.fromLTWH(10, height - 10 - cornerSize, cornerSize, cornerSize),
        Rect.fromLTWH(width - 10 - cornerSize, height - 10 - cornerSize,
            cornerSize, cornerSize),
      ];

      for (final rect in corners) {
        canvas.drawRect(rect, cornerGlowPaint);
        canvas.drawRect(rect, cornerPaint);
      }

      // 4.75 Draw Stylized Title Header
      final String phaseTitle = widget.isSideQuest
          ? "Bonus Side-Quest"
          : "Orbital Phase ${widget.index + 1}";

      final Rect textBounds = Rect.fromLTWH(0, 0, width, 100);
      final Shader textShader = widget.isSideQuest
          ? const LinearGradient(
              colors: [
                Colors.amberAccent,
                Colors.white,
                Colors.orangeAccent,
                Colors.amberAccent
              ],
              stops: [0.0, 0.4, 0.7, 1.0],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(textBounds)
          : const LinearGradient(
              colors: [Colors.white, Colors.white70],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ).createShader(textBounds);

      final titleStyle = TextStyle(
        foreground: Paint()..shader = textShader,
        fontSize: image.width * 0.08,
        fontWeight: FontWeight.w900,
        letterSpacing: 2.0,
        shadows: [
          Shadow(color: atmosphere.primaryGlow, blurRadius: 15.0),
          Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 4.0,
              offset: const Offset(2, 2)),
        ],
      );

      final titlePainter = TextPainter(
        text: TextSpan(text: phaseTitle, style: titleStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      titlePainter.layout(maxWidth: width - 60);

      titlePainter.paint(
        canvas,
        Offset((width - titlePainter.width) / 2,
            45), // Top center, padded down slightly
      );

      // 4.8 Draw Dynamic QR Code (Bottom Left)
      final qrValidationResult = QrValidator.validate(
        data:
            'https://orbitapp.io/download', // Replace with your actual app link!
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
      );

      if (qrValidationResult.status == QrValidationStatus.valid) {
        final qrCode = qrValidationResult.qrCode!;
        final double qrSize = image.width * 0.18; // 18% of image width

        final qrPainter = QrPainter.withQr(
          qr: qrCode,
          color: Colors.white.withValues(alpha: 0.9),
          emptyColor: Colors.transparent,
          gapless: true,
        );

        final double qrX = image.width * 0.05;
        final double qrY = image.height - qrSize - (image.height * 0.05) - 20;

        canvas.save();
        canvas.translate(qrX, qrY);

        // Draw QR Code
        qrPainter.paint(canvas, Size(qrSize, qrSize));

        // Draw Circular White Background & Logo
        if (qrLogoImage != null) {
          final center = Offset(qrSize / 2, qrSize / 2);
          final logoSize = qrSize * 0.25;

          canvas.drawCircle(
              center, (logoSize / 2) + 6, Paint()..color = Colors.white);

          paintImage(
            canvas: canvas,
            rect: Rect.fromCenter(
                center: center, width: logoSize, height: logoSize),
            image: qrLogoImage,
            fit: BoxFit.contain,
          );
        }
        canvas.restore();

        // Draw "SCAN TO JOIN" label below it
        final qrLabelStyle = TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: image.width * 0.025,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        );
        final qrLabelPainter = TextPainter(
          text: TextSpan(text: 'SCAN TO JOIN', style: qrLabelStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        qrLabelPainter.layout(maxWidth: qrSize * 1.5);
        qrLabelPainter.paint(
            canvas,
            Offset(
                qrX + (qrSize - qrLabelPainter.width) / 2, qrY + qrSize + 8));
      }

      // 5. Draw Watermark (Avatar, Username & Streak with dynamic Star!)
      final user = FirebaseAuth.instance.currentUser;
      final username = user?.displayName ?? 'Commander';

      IconData avatarIcon = Icons.rocket_launch_rounded;
      switch (avatarName.toLowerCase()) {
        case 'astronaut':
          avatarIcon = Icons.accessibility_new_rounded;
          break;
        case 'alien':
          avatarIcon = Icons.face_retouching_natural_rounded;
          break;
        case 'planet':
          avatarIcon = Icons.public_rounded;
          break;
        case 'star':
          avatarIcon = Icons.star_rounded;
          break;
        case 'moon':
          avatarIcon = Icons.nightlight_round;
          break;
      }

      final double fontSize = image.width * 0.05;
      final baseStyle = TextStyle(
        color: Colors.white.withValues(alpha: 0.8),
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: const Offset(1, 1),
            blurRadius: 3.0,
            color: Colors.black.withValues(alpha: 0.8),
          ),
        ],
      );
      final starStyle = TextStyle(
        color: Colors.amberAccent,
        fontSize: fontSize,
        fontFamily: Icons.star_rounded.fontFamily,
        package: Icons.star_rounded.fontPackage,
        shadows: baseStyle.shadows,
      );
      final avatarStyle = TextStyle(
        color: Colors.white,
        fontSize: fontSize * 1.1,
        fontFamily: avatarIcon.fontFamily,
        package: avatarIcon.fontPackage,
        shadows: baseStyle.shadows,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${String.fromCharCode(avatarIcon.codePoint)} ',
              style: avatarStyle,
            ),
            TextSpan(text: '@$username • $streak ', style: baseStyle),
            TextSpan(
              text: String.fromCharCode(Icons.star_rounded.codePoint),
              style: starStyle,
            ),
            TextSpan(text: ' Day Streak • Orbit', style: baseStyle),
          ],
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Position it in the bottom right corner
      textPainter.paint(
        canvas,
        Offset(
          image.width - textPainter.width - (image.width * 0.05),
          image.height - textPainter.height - (image.height * 0.05),
        ),
      );

      // 5. Convert back to bytes!
      final watermarkedImage =
          await recorder.endRecording().toImage(image.width, image.height);
      final watermarkedByteData =
          await watermarkedImage.toByteData(format: ImageByteFormat.png);
      return watermarkedByteData!.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  void _showMilestoneDialog(AtmosphereProvider atmosphereProvider) {
    final streak = context.read<RoutineProvider>().currentStreak;

    final aiService = AIFairyService();
    final futureInteraction = aiService.getFairyInteraction(
        widget.isSideQuest ? "Bonus Phase" : "Phase ${widget.index + 1}");

    bool isDialogOpen = true;
    Timer? autoCloseTimer;
    bool isSaving = false;
    bool interactionSaved = false;

    showDialog(
      context: context,
      builder: (_) {
        double tiltX = 0.0;
        double tiltY = 0.0;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: atmosphereProvider.primaryGlow),
                  const SizedBox(width: 8),
                  Text(widget.isSideQuest
                      ? "Bonus Loot Discovered!"
                      : "Milestone Unlocked!"),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<AIFairyResponse>(
                    future: futureInteraction,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: atmosphereProvider.primaryGlow,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "The Fairy is sensing the cosmos...",
                                style: TextStyle(
                                    color: atmosphereProvider.primaryGlow,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }

                      final fairyMessage = snapshot.data?.text ??
                          "A $streak-day streak is a great start. Keep your orbit steady! 🚀";
                      final options = snapshot.data?.options ?? [];

                      return Column(
                        children: [
                          AIFairyBubble(message: fairyMessage)
                              .animate()
                              .shakeX(hz: 8, amount: 3, duration: 400.ms)
                              .shimmer(
                                  color: Colors.cyanAccent, duration: 400.ms)
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(
                                  begin: -3,
                                  end: 3,
                                  duration: 2.seconds,
                                  curve: Curves.easeInOut),
                          if (options.isNotEmpty && !interactionSaved)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: options
                                    .map((opt) => ActionChip(
                                          label: Text(opt,
                                              style: const TextStyle(
                                                  fontSize: 11)),
                                          backgroundColor: atmosphereProvider
                                              .primaryGlow
                                              .withValues(alpha: 0.1),
                                          side: BorderSide(
                                              color: atmosphereProvider
                                                  .primaryGlow
                                                  .withValues(alpha: 0.3)),
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            setState(
                                                () => interactionSaved = true);
                                            aiService.saveInteraction(
                                                "Phase ${widget.index + 1}",
                                                fairyMessage,
                                                opt);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: Text(
                                                  "The Fairy received your energy: $opt"),
                                              backgroundColor:
                                                  atmosphereProvider
                                                      .primaryGlow,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ));
                                          },
                                        ))
                                    .toList(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.isSideQuest
                        ? "You've uncovered a rare cosmic artifact by exploring this side-path. The universe rewards your curiosity!"
                        : "You've successfully reached Phase ${widget.index + 1}. The cosmos applauds your consistency!",
                  ),
                  const SizedBox(height: 24),

                  // --- IN-APP ANIMATED QR CODE ---
                  GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        tiltX += details.delta.dy * -0.01;
                        tiltY += details.delta.dx * 0.01;
                        tiltX = tiltX.clamp(-0.15, 0.15);
                        tiltY = tiltY.clamp(-0.15, 0.15);
                      });
                    },
                    onPanEnd: (_) => setState(() {
                      tiltX = 0;
                      tiltY = 0;
                    }),
                    onPanCancel: () => setState(() {
                      tiltX = 0;
                      tiltY = 0;
                    }),
                    child: TweenAnimationBuilder(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      tween: Tween<Offset>(
                          begin: Offset.zero, end: Offset(tiltX, tiltY)),
                      builder: (context, Offset tilt, child) {
                        final matrix = Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateX(tilt.dx)
                          ..rotateY(tilt.dy);
                        return Transform(
                          transform: matrix,
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: atmosphereProvider.primaryGlow
                                  .withValues(alpha: 0.5),
                              width: 2),
                        ),
                        clipBehavior:
                            Clip.hardEdge, // Keeps the scanline contained!
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: 'https://orbitapp.io/download',
                              version: QrVersions.auto,
                              size: 120,
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                            ),
                            Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Image.asset('assets/icons/icon.png',
                                  width: 24, height: 24),
                            ),

                            // Glowing Scanline Animation!
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: atmosphereProvider.accentColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: atmosphereProvider.accentColor,
                                      blurRadius: 12,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ).animate(onPlay: (c) => c.loop()).moveY(
                                  begin: -20,
                                  end: 160,
                                  duration: 2.seconds,
                                  curve: Curves.easeInOutSine),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            duration: 600.ms,
                            curve: Curves.easeOutBack,
                          )
                          .rotate(
                            begin:
                                -0.1, // Starts slightly rotated (-36 degrees) and snaps to 0!
                            end: 0.0,
                            duration: 600.ms,
                            curve: Curves.easeOutBack,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "SCAN TO JOIN ORBIT",
                    style: TextStyle(
                      color: atmosphereProvider.primaryGlow,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fade(begin: 0.4, end: 1.0, duration: 1.seconds),
                  const SizedBox(height: 16),
                  // --- AUTO-CLOSE COUNTDOWN BAR ---
                  TweenAnimationBuilder<double>(
                    duration: const Duration(seconds: 15),
                    tween: Tween<double>(begin: 1.0, end: 0.0),
                    builder: (context, value, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor: atmosphereProvider.primaryGlow
                              .withValues(alpha: 0.2),
                          color: Color.lerp(
                              Colors.redAccent, Colors.greenAccent, value),
                          minHeight: 4,
                        ),
                      );
                    },
                  )
                      .animate(
                          delay: 12.seconds,
                          onPlay: (c) => c.loop(reverse: true))
                      .fade(begin: 1.0, end: 0.4, duration: 200.ms)
                      .scaleXY(begin: 1.0, end: 1.02, duration: 200.ms),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setState(() => isSaving = true);
                          try {
                            // 1. Check and request gallery access first!
                            final hasAccess = await Gal.hasAccess();
                            if (!hasAccess) {
                              final granted = await Gal.requestAccess();
                              if (!granted) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          "Gallery access is required. Please enable it in Settings."),
                                      backgroundColor: Colors.redAccent,
                                      action: SnackBarAction(
                                        label: 'Settings',
                                        textColor: Colors.white,
                                        onPressed: () => openAppSettings(),
                                      ),
                                    ),
                                  );
                                }
                                return; // Exit early if they deny permission
                              }
                            }

                            final imageBytes =
                                await _generateWatermarkedImage();
                            if (imageBytes != null) {
                              await Gal.putImageBytes(imageBytes);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        const Text("Saved to Photo Gallery!"),
                                    backgroundColor:
                                        atmosphereProvider.primaryGlow,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Failed to save image."),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => isSaving = false);
                            }
                          }
                        },
                  icon: isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: atmosphereProvider.primaryGlow,
                          ),
                        )
                      : const Icon(Icons.save_alt_rounded),
                  label: Text(isSaving ? "Saving..." : "Save"),
                  style: TextButton.styleFrom(
                    foregroundColor: atmosphereProvider.primaryGlow,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final streak =
                        context.read<RoutineProvider>().currentStreak;
                    final shareText = widget.isSideQuest
                        ? "🚀 I just uncovered rare Bonus Loot on my Orbit journey with a $streak day streak! Join me."
                        : "🚀 I just completed Phase ${widget.index + 1} and hit a $streak day streak in Orbit! Join me in building better habits.";

                    final imageBytes = await _generateWatermarkedImage();
                    if (imageBytes != null) {
                      final xFile = XFile.fromData(
                        imageBytes,
                        mimeType: 'image/png',
                        name: 'milestone_${widget.index}_watermarked.png',
                      );
                      await Share.shareXFiles([xFile], text: shareText);
                    } else {
                      await Share.share(shareText);
                    }
                  },
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text("Share"),
                  style: TextButton.styleFrom(
                    foregroundColor: atmosphereProvider.primaryGlow,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    "Continue Journey",
                    style: TextStyle(
                        color: atmosphereProvider.accentColor,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Triggers if the user manually dismisses or taps "Continue"
      isDialogOpen = false;
      autoCloseTimer?.cancel();
    });

    autoCloseTimer = Timer(const Duration(seconds: 15), () {
      if (isDialogOpen && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });
  }
}

// Moved outside of the MilestoneTileState correctly!
class _StardustParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double alpha;
  Color color;

  _StardustParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.alpha,
    required this.color,
  });
}
