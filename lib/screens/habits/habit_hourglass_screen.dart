import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/base_orbit_screen.dart';
import '../../widgets/common/premium_glass_card.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';

class HabitHourglassScreen extends StatefulWidget {
  final String habitTitle;
  final int durationMinutes;

  const HabitHourglassScreen({
    super.key,
    required this.habitTitle,
    this.durationMinutes = 25, // Default to a 25-minute focus session
  });

  @override
  State<HabitHourglassScreen> createState() => _HabitHourglassScreenState();
}

class _HabitHourglassScreenState extends State<HabitHourglassScreen>
    with TickerProviderStateMixin {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;

  late AnimationController _pulseController;
  late RoutineProvider _routineProvider;
  bool _shouldStopAmbientOnDispose = false;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.durationMinutes * 60;
    _remainingSeconds = _totalSeconds;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _routineProvider = context.read<RoutineProvider>();
  }

  void _stopAmbientIfNeeded() {
    if (_shouldStopAmbientOnDispose && _routineProvider.isPlayingAmbient) {
      _routineProvider.stopAmbientAudio();
      _shouldStopAmbientOnDispose = false;
    }
  }

  @override
  void dispose() {
    _stopAmbientIfNeeded();
    _timer?.cancel();
    _pulseController.dispose();
    WakelockPlus.disable(); // Ensure screen can sleep when leaving the screen
    super.dispose();
  }

  void _toggleTimer() {
    HapticFeedback.mediumImpact();
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    setState(() => _isRunning = true);
    WakelockPlus.enable(); // Keep the screen awake!

    // Automatically play ambient audio during focus session
    if (!_routineProvider.isPlayingAmbient) {
      _shouldStopAmbientOnDispose = true;
      _routineProvider.toggleAmbientAudio();
    }

    _pulseController.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);

        // Speed up the ambient pulsing when less than 1 minute remains!
        if (_remainingSeconds == 59) {
          _pulseController.duration = const Duration(milliseconds: 500);
          _pulseController.repeat(reverse: true);
        }
      } else {
        _timer?.cancel();
        setState(() => _isRunning = false);
        _pulseController.stop();
        WakelockPlus.disable();
        HapticFeedback.heavyImpact();
        _stopAmbientIfNeeded();
        _showCompletionDialog();
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
    _pulseController.stop();
    WakelockPlus.disable(); // Let the screen sleep if paused
  }

  void _resetTimer() {
    HapticFeedback.lightImpact();
    _pauseTimer();
    setState(() {
      _remainingSeconds = _totalSeconds;
      _pulseController.duration =
          const Duration(seconds: 2); // Reset pulse speed
    });
  }

  String get _formattedTime {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Stellar Focus!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'You successfully completed your focus session. The universe rewards your discipline.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Return to Orbit'),
          ),
        ],
      ),
    );
  }

  void _showSkipReasonDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Skip Session',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why are you skipping this session? Logging this helps you identify patterns over time.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g., Not enough time, too tired...',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () async {
              HapticFeedback.lightImpact();
              final reason = reasonController.text.trim();

              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('skipped_sessions')
                      .add({
                    'habitTitle': widget.habitTitle,
                    'reason': reason.isNotEmpty ? reason : 'No reason provided',
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                } catch (e) {
                  debugPrint("Failed to log skipped session: $e");
                }
              }

              // Schedule a local reminder for 2 hours from now
              await NotificationService.scheduleReattemptReminder(
                  widget.habitTitle, const Duration(hours: 2));

              if (mounted && context.mounted) {
                Navigator.pop(context); // Close the dialog
                _stopAmbientIfNeeded();
                Navigator.pop(context); // Close the hourglass screen
              }
            },
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPlayingAmbient = context.watch<RoutineProvider>().isPlayingAmbient;
    // Reversing the progress so the ring "depletes" like an hourglass emptying!
    final double progress = _remainingSeconds / _totalSeconds;
    final theme = Theme.of(context);
    final Color textColor = theme.colorScheme.onSurface;

    return BaseOrbitScreen(
      title: 'Focus',
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Background Glow
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(
                          alpha: _isRunning
                              ? 0.1 + (_pulseController.value * 0.15)
                              : 0.0),
                      blurRadius: 100,
                      spreadRadius: 50,
                    ),
                  ],
                ),
              );
            },
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.habitTitle.toUpperCase(),
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ).animate().fade().slideY(begin: -0.2),

              const SizedBox(height: 40),

              // The Cosmic Hourglass Timer
              SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Track
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          textColor.withValues(alpha: 0.05),
                        ),
                      ),
                    ),

                    // Animated Progress Ring
                    SizedBox(
                      width: 280,
                      height: 280,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF00E5FF),
                        ),
                      ),
                    ),

                    // Cosmic Sand (Falling Particles)
                    if (_isRunning)
                      ...List.generate(12, (index) {
                        // Pseudo-random offset based on index so it doesn't jitter on setState
                        final double offset = (index * 47) % 60 - 30.0;
                        final delay = (index * 166).ms;

                        return Positioned(
                          top: 20,
                          left: 140 + offset, // Center is 140
                          child: Container(
                            width: 3,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(1.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFF00E5FF),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate(onPlay: (c) => c.loop(), delay: delay)
                            .moveY(
                                begin: 0,
                                end: 240,
                                duration: 2.seconds,
                                curve: Curves.easeIn)
                            .fade(begin: 0, end: 1, duration: 300.ms)
                            .fadeOut(delay: 1700.ms, duration: 300.ms);
                      }),

                    // Inner Time Text
                    PremiumGlassCard(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formattedTime,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 56,
                              fontWeight: FontWeight.w300,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRunning ? 'FOCUSING' : 'PAUSED',
                            style: TextStyle(
                              color: _isRunning
                                  ? const Color(0xFF00E5FF)
                                  : textColor.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          if (isPlayingAmbient) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 16,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(5, (index) {
                                  return Container(
                                    width: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF)
                                          .withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  )
                                      .animate(
                                          onPlay: (c) => c.loop(reverse: true))
                                      .scaleY(
                                        begin: 0.3,
                                        end: 1.0,
                                        delay: (index * 150 % 400).ms,
                                        duration: 400.ms,
                                        curve: Curves.easeInOutSine,
                                      );
                                }),
                              ),
                            ).animate().fade(duration: 300.ms),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().scale(
                  delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 60),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Reset Button
                  IconButton(
                    onPressed: _resetTimer,
                    icon: Icon(Icons.refresh_rounded,
                        color: textColor.withValues(alpha: 0.5)),
                    iconSize: 32,
                  ).animate().fade(delay: 400.ms),

                  const SizedBox(width: 32),

                  // Play/Pause Button
                  GestureDetector(
                    onTap: _toggleTimer,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _isRunning
                            ? textColor.withValues(alpha: 0.1)
                            : const Color(0xFF00E5FF),
                        shape: BoxShape.circle,
                        boxShadow: _isRunning
                            ? []
                            : [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                      ),
                      child: Icon(
                        _isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: _isRunning ? textColor : Colors.black,
                        size: 40,
                      ),
                    ),
                  ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),

                  const SizedBox(width: 32),

                  // Stop Button
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _stopAmbientIfNeeded();
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.stop_rounded,
                        color: textColor.withValues(alpha: 0.5)),
                    iconSize: 32,
                  ).animate().fade(delay: 400.ms),
                ],
              ),

              const SizedBox(height: 24),

              // Skip Button
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showSkipReasonDialog();
                },
                child: Text(
                  'Skip this session',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.5),
                    fontSize: 16,
                  ),
                ),
              ).animate().fade(delay: 600.ms),
            ],
          ),
        ],
      ),
    );
  }
}
