import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // NEW
import '../../providers/routine_provider.dart'; // NEW
import '../../providers/ai_fairy_provider.dart';
import '../../models/habit.dart';
import 'package:confetti/confetti.dart';
import '../../widgets/orbit_confetti.dart';
import '../../widgets/routine_app_bar.dart';
import '../../widgets/routine_header_info.dart';
import '../../widgets/routine_habit_list.dart';
import '../../widgets/routine_play_button.dart';
import '../../widgets/common/ai_fairy_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:audioplayers/audioplayers.dart';

class RoutineDetailScreen extends StatefulWidget {
  final String title;
  final String time;
  final String routineType; // 'Morning', 'Work', or 'Night'
  final List<Color> gradientColors;
  final String coachingAudioTitle;

  const RoutineDetailScreen({
    super.key,
    required this.title,
    required this.time,
    required this.routineType, // REQUIRED NOW
    required this.gradientColors,
    required this.coachingAudioTitle,
  });

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late ConfettiController _confettiController;
  late ConfettiController _explosiveConfettiController;
  late TextEditingController _rewardController;
  bool _showSuccessCheck = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _explosiveConfettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _rewardController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rewardController.text = context
            .read<RoutineProvider>()
            .getRoutineReward(widget.routineType);
      }
    });
  }

  @override
  void dispose() {
    _rewardController.dispose();
    _confettiController.dispose();
    _explosiveConfettiController.dispose();
    super.dispose();
  }

  void _toggleAndCheckConfetti(String habitId) {
    final provider = context.read<RoutineProvider>();
    final targetHabit = provider.habits[habitId];
    if (targetHabit == null) return;

    bool wasComplete = provider.isRoutineComplete(widget.routineType);
    bool wasHabitComplete = targetHabit.isCompleted;

    if (!wasHabitComplete) {
      AudioPlayer().play(AssetSource('audio/success_chime.mp3'));
      setState(() => _showSuccessCheck = true);
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showSuccessCheck = false);
      });

      // Trigger the AI Fairy Cheer!
      context
          .read<AIFairyProvider>()
          .cheerForHabit(targetHabit.title, provider.currentStreak);
    }

    provider.toggleHabit(habitId).then((_) {
      if (provider.justLeveledUp) {
        _showLevelUpDialog(provider.currentLevel);
        provider.acknowledgeLevelUp();
      }
    });

    if (!wasComplete && provider.isRoutineComplete(widget.routineType)) {
      bool isNewLongest = provider.markRoutineComplete();
      if (isNewLongest) {
        _explosiveConfettiController.play();
      } else {
        _confettiController.play();
      }
    }
  }

  void _showLevelUpDialog(int level) {
    HapticFeedback.heavyImpact();
    _explosiveConfettiController.play();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF13002B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amber, size: 80)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.9, end: 1.1, duration: 1.seconds),
            const SizedBox(height: 24),
            const Text('Level Up!',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You are now Level $level',
                style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
                'Keep completing habits to earn more XP and reach the stars.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Awesome!',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ).animate().scaleXY(begin: 0.8, end: 1.0, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    // READ THE LIVE LIST FROM THE BRAIN!
    final liveHabits = context
        .watch<RoutineProvider>()
        .getHabitsForRoutine(widget.routineType);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              RoutineAppBar(
                routineType: widget.routineType,
                gradientColors: widget.gradientColors,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      RoutineHeaderInfo(
                        habitCount: liveHabits.length,
                        routineType: widget.routineType,
                        title: widget.title,
                      )
                          .animate(delay: 200.ms)
                          .shimmer(duration: 1000.ms, color: Colors.white24),
                      const SizedBox(height: 24),
                      RoutinePlayButton(audioTitle: widget.coachingAudioTitle),
                      const SizedBox(height: 32),

                      // THE EXTRACTED ROUTINE HABIT LIST
                      RoutineHabitList(
                        habits: liveHabits,
                        onHabitToggled: _toggleAndCheckConfetti,
                      ).animate(delay: 400.ms).fade(duration: 600.ms).slideY(
                          begin: 0.2, end: 0, curve: Curves.easeOutCubic),

                      if (context
                          .watch<RoutineProvider>()
                          .isRoutineComplete(widget.routineType)) ...[
                        if (context
                            .watch<RoutineProvider>()
                            .getRoutineReward(widget.routineType)
                            .isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.amber.withValues(alpha: 0.5),
                                  width: 2),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.redeem_rounded,
                                    color: Colors.amber, size: 32),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Goal Reached!',
                                          style: TextStyle(
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(
                                          'Reward: ${context.watch<RoutineProvider>().getRoutineReward(widget.routineType)}',
                                          style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate().scaleXY(
                              begin: 0.9, end: 1.0, curve: Curves.easeOutBack),
                      ] else ...[
                        TextField(
                          controller: _rewardController,
                          onSubmitted: (val) {
                            context
                                .read<RoutineProvider>()
                                .setRoutineReward(widget.routineType, val);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Custom reward saved! 🎁'),
                                  backgroundColor: Colors.green),
                            );
                          },
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Set a custom reward for finishing...',
                            hintStyle: const TextStyle(color: Colors.black38),
                            prefixIcon: const Icon(Icons.card_giftcard_rounded,
                                color: Colors.black38),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color:
                                        Colors.black.withValues(alpha: 0.05))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color:
                                        Colors.black.withValues(alpha: 0.05))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: Colors.amber, width: 2)),
                          ),
                        ).animate(delay: 600.ms).fade().slideY(begin: 0.2),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 32),
                      if (!context
                          .watch<RoutineProvider>()
                          .isRoutineComplete(widget.routineType))
                        TextButton.icon(
                          onPressed: () {
                            final result = context
                                .read<RoutineProvider>()
                                .skipRoutine(widget.routineType);
                            Navigator.pop(context);
                            if (result != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Routine skipped.'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () {
                                      context
                                          .read<RoutineProvider>()
                                          .undoSkipRoutine(
                                            List<Habit>.from(
                                                result['skippedHabits']
                                                    as List),
                                            result['streakIncreased'] as bool,
                                            result['isNewLongest'] as bool,
                                          );
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.fast_forward_rounded,
                              color: Colors.grey),
                          label: const Text('Skip Rest of Routine',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ).animate().fade(delay: 800.ms),
                    ],
                  ),
                ),
              )
            ],
          ),
          // THE CONFETTI OVERLAY
          Align(
            alignment: Alignment.topCenter,
            child: OrbitConfetti(controller: _confettiController),
          ),
          Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _explosiveConfettiController,
              blastDirectionality:
                  BlastDirectionality.explosive, // Burst from center
              maxBlastForce: 40,
              minBlastForce: 20,
              emissionFrequency: 0.1,
              numberOfParticles: 30,
              gravity: 0.1,
              colors: const [
                Colors.lightBlueAccent,
                Colors.cyanAccent,
                Colors.white
              ],
            ),
          ),
          if (_showSuccessCheck)
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFF00E5FF),
                          Color(0xFF7000FF),
                          Colors.amber,
                          Color(0xFF00E5FF),
                        ],
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat())
                      .rotate(duration: 2.seconds),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: Color(0xFFF5F6F8)),
                  ),
                  const Icon(Icons.check_circle_rounded,
                      size: 120, color: Color(0xFF00E5FF)),
                ],
              )
                  .animate()
                  .scaleXY(
                      begin: 0.5,
                      end: 1.0,
                      duration: 400.ms,
                      curve: Curves.easeOutBack)
                  .fadeOut(delay: 800.ms, duration: 400.ms),
            ),
          // THE AI FAIRY OVERLAY
          const Align(
            alignment: Alignment.bottomCenter,
            child: AIFairyOverlay(),
          ),
        ],
      ),
    );
  }
}
