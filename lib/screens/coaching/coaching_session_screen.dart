import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:orbit_app/services/cosmic_mirror_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/orbit_tokens.dart';

// --- DIALOGUE DATA MODELS ---
class CoachingNode {
  final String id;
  final List<String> fairyMessages;
  final List<CoachingOption> options;
  final bool isInput;

  CoachingNode({
    required this.id,
    required dynamic fairyMessage,
    this.options = const [],
    this.isInput = false,
  }) : fairyMessages = fairyMessage is List<String>
           ? fairyMessage
           : [fairyMessage.toString()];

  // This getter dynamically pulsl a message when the node is displayed
  String get displayMessage {
    if (fairyMessages.isEmpty) return '';
    if (fairyMessages.length == 1) return fairyMessages.first;

    // Pick a truly random message from the pool
    final random = Random();
    return fairyMessages[random.nextInt(fairyMessages.length)];
  }
}

class CoachingOption {
  final String text;
  final String nextNodeId;

  CoachingOption({required this.text, required this.nextNodeId});
}

// --- THE SCREEN ---
class CoachingSessionScreen extends StatefulWidget {
  final String sessionType; // 'daily', 'workday', or 'nightly'

  const CoachingSessionScreen({super.key, required this.sessionType});

  @override
  State<CoachingSessionScreen> createState() => _CoachingSessionScreenState();
}

class _CoachingSessionScreenState extends State<CoachingSessionScreen> {
  late RoutineProvider _routineProvider;
  late Map<String, CoachingNode> _currentTree;
  String _currentNodeId = 'start';
  final TextEditingController _noteController = TextEditingController();
  Future<String>? _messageFuture;
  String? _selectedMood;
  final AudioPlayer _hypnoticAudioPlayer = AudioPlayer();

  // --- HARDCODED TREES ---
  final Map<String, CoachingNode> _dailyTree = {
    'start': CoachingNode(
      id: 'start',
      fairyMessage:
          'Good morning, Commander. A new solar cycle begins. How are your systems calibrating today?',
      options: [
        CoachingOption(text: 'Ready to launch', nextNodeId: 'launch'),
        CoachingOption(text: 'A bit sluggish', nextNodeId: 'sluggish'),
      ],
    ),
    'launch': CoachingNode(
      id: 'launch',
      fairyMessage: [
        'Momentum is on your side. Let\'s channel that energy.',
        'A perfect start sequence. Let\'s lock in your coordinates.',
      ],
      options: [
        CoachingOption(text: 'Set my intention', nextNodeId: 'input_dynamic'),
      ],
    ),
    'sluggish': CoachingNode(
      id: 'sluggish',
      fairyMessage: [
        'Even the brightest stars take time to ignite. Let\'s start with a gentle engine warm-up. Take a slow, deep breath in... and out.',
        'Gravity feels heavier some mornings. Let\'s lower the thrusters and ease into orbit. Just breathe.',
      ],
      options: [
        CoachingOption(text: 'I\'m ready now', nextNodeId: 'input_dynamic'),
      ],
    ),
    'input_dynamic': CoachingNode(
      id: 'input_dynamic',
      fairyMessage: [
        'What is the single most vital intention you want to set for this solar cycle?',
        'If you could accomplish just one meaningful thing today, what would it be?',
      ],
      isInput: true,
    ),
    'done_dynamic': CoachingNode(
      id: 'done_dynamic',
      fairyMessage: [
        'Morning alignment complete. Your intention to "[INTENTION]" is locked in. Have a stellar day, Commander.',
        'Trajectory set. Carry "[INTENTION]" with you as you navigate the stars today. End of transmission.',
      ],
      options: [CoachingOption(text: 'Finish Session', nextNodeId: 'exit')],
    ),
  };

  final Map<String, CoachingNode> _workdayTree = {
    'start': CoachingNode(
      id: 'start',
      fairyMessage:
          'Mid-flight check-in, Commander. How are the atmospheric conditions out there?',
      options: [
        CoachingOption(text: 'Cruising smoothly', nextNodeId: 'smooth'),
        CoachingOption(text: 'Navigating turbulence', nextNodeId: 'turbulence'),
      ],
    ),
    'smooth': CoachingNode(
      id: 'smooth',
      fairyMessage: [
        'Excellent. Keep your velocity steady and maintain your heading.',
        'Clear skies ahead. Let\'s keep the thrusters humming at optimal efficiency.',
      ],
      options: [
        CoachingOption(text: 'Lock it in', nextNodeId: 'input_dynamic'),
      ],
    ),
    'turbulence': CoachingNode(
      id: 'turbulence',
      fairyMessage: [
        'Turbulence is normal. Let\'s run a quick diagnostic. Are you feeling overwhelmed by tasks, or distracted by noise?',
      ],
      options: [
        CoachingOption(text: 'Too many tasks', nextNodeId: 'overwhelmed'),
        CoachingOption(text: 'Too much noise', nextNodeId: 'distracted'),
      ],
    ),
    'overwhelmed': CoachingNode(
      id: 'overwhelmed',
      fairyMessage: [
        'When the dashboard lights up with warnings, focus on the single most critical system. Pick one task. Ground yourself. Everything else can wait.',
      ],
      options: [
        CoachingOption(text: 'Recalibrating...', nextNodeId: 'input_dynamic'),
      ],
    ),
    'distracted': CoachingNode(
      id: 'distracted',
      fairyMessage: [
        'Cosmic static can scramble your sensors. Take 60 seconds to step away from the monitors, close your eyes, and reset your frequency.',
      ],
      options: [
        CoachingOption(text: 'Frequency reset', nextNodeId: 'input_dynamic'),
      ],
    ),
    'input_dynamic': CoachingNode(
      id: 'input_dynamic',
      fairyMessage: [
        'To stabilize your orbit for the rest of the day, what is your primary focus from here?',
        'Write down the one thing you need to prioritize before power-down today.',
      ],
      isInput: true,
    ),
    'done_dynamic': CoachingNode(
      id: 'done_dynamic',
      fairyMessage: [
        'Course corrected. Focus on "[INTENTION]". You have the navigation data you need. Godspeed.',
        'Mid-day alignment complete. Remember your commitment to "[INTENTION]". Returning you to the helm.',
      ],
      options: [CoachingOption(text: 'Finish Session', nextNodeId: 'exit')],
    ),
  };

  final Map<String, CoachingNode> _weeklyReviewTree = {
    'start': CoachingNode(
      id: 'start',
      fairyMessage:
          'You have returned to the Cosmic Mirror to reflect upon your journey. The stars have recorded your efforts. Let us gaze into the nebula of your past week.',
      options: [
        CoachingOption(text: 'Reveal my legend', nextNodeId: 'legend_dynamic'),
      ],
    ),
    'legend_dynamic': CoachingNode(
      id: 'legend_dynamic',
      fairyMessage: 'Generating your weekly legend...', // Placeholder
      options: [CoachingOption(text: 'Finish Session', nextNodeId: 'exit')],
    ),
  };
  // --- UPGRADED HARDCODED TREES ---
  final Map<String, CoachingNode> _nightlyTree = {
    'start': CoachingNode(
      id: 'start',
      fairyMessage:
          'What kind of support do you need for consulting the mirror right now?',
      options: [
        CoachingOption(text: 'Motivate me', nextNodeId: 'motivate'),
        CoachingOption(text: 'Adjust to how I feel', nextNodeId: 'adjust'),
      ],
    ),

    'motivate': CoachingNode(
      id: 'motivate',
      fairyMessage: 'Choose your cosmic focus tonight:',
      options: [
        CoachingOption(
          text: 'To improve my mental health',
          nextNodeId: 'mental',
        ),
        CoachingOption(text: 'To feel more relaxed', nextNodeId: 'relaxed'),
        CoachingOption(text: 'To enhance my focus', nextNodeId: 'focused'),
      ],
    ),

    'adjust': CoachingNode(
      id: 'adjust',
      fairyMessage:
          'It is okay to slow down. Let us lower the gravity, dim the starlight, and take a gentle approach tonight.',
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    // --- MENTAL HEALTH BRANCH ---
    'mental': CoachingNode(
      id: 'mental',
      fairyMessage:
          'When you feel your mental space getting crowded, what is the very first signal your system gives you?',
      options: [
        CoachingOption(text: 'A tightness in my chest', nextNodeId: 'mental_2'),
        CoachingOption(text: 'A racing heart', nextNodeId: 'mental_dynamic'),
        CoachingOption(text: 'A wandering mind', nextNodeId: 'mental_dynamic'),
      ],
    ),

    'mental_2': CoachingNode(
      id: 'mental_2',
      fairyMessage:
          'When the pressure builds, it helps to visualize your thoughts as unmapped stars in a vast galaxy. They don\'t define the sky; they are just passing through it. Let\'s cultivate a constellation of calm.',
      options: [
        CoachingOption(
          text: 'Tap to continue',
          nextNodeId: 'mental_followup_2',
        ),
      ],
    ),

    'mental_dynamic': CoachingNode(
      id: 'mental_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'mental_followup'),
      ],
    ),

    'mental_followup': CoachingNode(
      id: 'mental_followup',
      fairyMessage:
          'What is one tiny, non-negotiable ritual you want to anchor into your morning routine this week?',
      options: [
        CoachingOption(
          text: 'Mindfulness meditation',
          nextNodeId: 'meditation_dynamic',
        ),
        CoachingOption(
          text: 'Journaling to clear the noise',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'A short walk under the open sky',
          nextNodeId: 'fact_dynamic',
        ),
      ],
    ),

    'mental_followup_2': CoachingNode(
      id: 'mental_followup_2',
      fairyMessage: 'What do you struggle with more heavily right now?',
      options: [
        CoachingOption(
          text: 'Feeling overwhelmed by static',
          nextNodeId: 'mental_space',
        ),
        CoachingOption(
          text: 'Powering down to fall asleep',
          nextNodeId: 'relaxed',
        ),
      ],
    ),

    'mental_space': CoachingNode(
      id: 'mental_space',
      fairyMessage:
          'A mirror reflects what is, but a cosmic mirror reveals what can be. Prioritizing your inner landscape is the ultimate form of personal alchemy.',
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    // --- RELAXED BRANCH ---
    'relaxed': CoachingNode(
      id: 'relaxed',
      fairyMessage:
          'When the atmospheric pressure gets too high, what classic anchor brings you back down to Earth?',
      options: [
        CoachingOption(
          text: 'Sinking into audio or music',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'Moving my body in nature',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'Complete silence and meditation',
          nextNodeId: 'meditation_dynamic',
        ),
      ],
    ),

    // --- FOCUS BRANCH ---
    'focused': CoachingNode(
      id: 'focused',
      fairyMessage:
          'In a universe full of continuous noise, deep focus is your ultimate superpower—it is the lens that directs your light. Let\'s fine-tune your frequency.',
      options: [
        CoachingOption(
          text: 'Calibrate my environment',
          nextNodeId: 'focus_dynamic',
        ),
        CoachingOption(
          text: 'Isolate my attention flaws',
          nextNodeId: 'focus_followup',
        ),
      ],
    ),

    'focus_dynamic': CoachingNode(
      id: 'focus_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [
        CoachingOption(
          text: 'Let\'s optimize it',
          nextNodeId: 'focus_followup',
        ),
      ],
    ),

    'focus_followup': CoachingNode(
      id: 'focus_followup',
      fairyMessage: 'Where does your beam of attention usually break down?',
      options: [
        CoachingOption(
          text: 'Initiating: Actually starting a task',
          nextNodeId: 'focus_followup_dynamic',
        ),
        CoachingOption(
          text: 'Sustaining: Staying on it once started',
          nextNodeId: 'focus_followup_dynamic',
        ),
      ],
    ),

    'focus_followup_dynamic': CoachingNode(
      id: 'focus_followup_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [
        CoachingOption(text: 'Lock it in', nextNodeId: 'fact_dynamic'),
        CoachingOption(
          text: 'I\'m still searching for clarity',
          nextNodeId: 'not_sure_dynamic',
        ),
      ],
    ),

    // --- NOT SURE / GENERAL UTILITY BRANCH ---
    'not_sure_dynamic': CoachingNode(
      id: 'not_sure_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [
        CoachingOption(
          text: 'A 5-minute mental reset',
          nextNodeId: 'meditation_dynamic',
        ),
        CoachingOption(
          text: 'Physical exertion and movement',
          nextNodeId: 'exercise_dynamic',
        ),
      ],
    ),

    'meditation_dynamic': CoachingNode(
      id: 'meditation_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    'exercise_dynamic': CoachingNode(
      id: 'exercise_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [
        CoachingOption(
          text: 'A brisk, meditative walk',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'Flow and deep yoga stretches',
          nextNodeId: 'fact_dynamic',
        ),
        CoachingOption(
          text: 'A high-intensity, heavy-duty workout',
          nextNodeId: 'workout_dynamic',
        ),
      ],
    ),

    'workout_dynamic': CoachingNode(
      id: 'workout_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [
        CoachingOption(text: 'Tap to continue', nextNodeId: 'fact_dynamic'),
      ],
    ),

    // --- THE CENTRAL CORE PIPELINE ---
    'fact_dynamic': CoachingNode(
      id: 'fact_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      options: [CoachingOption(text: 'Tap to continue', nextNodeId: 'breathe')],
    ),

    'breathe': CoachingNode(
      id: 'breathe',
      fairyMessage:
          'Just a few intentional, deep expansions can completely drop your heart rate and ground your nervous system. Let\'s take a slow breath together.',
      options: [
        CoachingOption(
          text: 'I\'ve taken a breath',
          nextNodeId: 'input_dynamic',
        ),
      ],
    ),

    'input_dynamic': CoachingNode(
      id: 'input_dynamic',
      fairyMessage: 'Generating wisdom...', // Placeholder
      isInput: true,
    ),

    'done_dynamic': CoachingNode(
      id: 'done_dynamic',
      fairyMessage: [
        'Beautifully anchored. Your intention to "[INTENTION]" is locked in. Your orbit is secure, and your trajectory is clear. Rest deeply, Commander.',
      ],
      options: [CoachingOption(text: 'Finish Session', nextNodeId: 'exit')],
    ),
  };

  // --- LIFECYCLE METHODS ---

  @override
  void initState() {
    super.initState();
    _fetchInitialMessage();
    _setupSession();
    _playHypnoticAudio();
  }

  Future<void> _playHypnoticAudio() async {
    try {
      _hypnoticAudioPlayer.setReleaseMode(ReleaseMode.loop);
      await _hypnoticAudioPlayer.setVolume(0.0);
      if (!mounted) return;

      await _hypnoticAudioPlayer.play(AssetSource('audio/hypnotic_loop.mp3'));
      if (!mounted) return;

      _fadeAudio(0.0, 0.3, const Duration(seconds: 2));
    } catch (e) {
      debugPrint("Hypnotic audio player interrupted: $e");
    }
  }

  Future<void> _fadeAudio(double start, double end, Duration duration) async {
    const int steps = 20;
    final stepDuration = duration ~/ steps;
    final volumeStep = (end - start) / steps;

    for (int i = 1; i <= steps; i++) {
      if (!mounted) return;
      final currentVolume = start + (volumeStep * i);
      await _hypnoticAudioPlayer.setVolume(currentVolume);
      await Future.delayed(stepDuration);
    }
  }

  Future<void> _handleExit() async {
    await _fadeAudio(0.3, 0.0, const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _setupSession() {
    // Select tree based on type
    if (widget.sessionType == 'daily') {
      _currentTree = _dailyTree;
    } else if (widget.sessionType == 'workday') {
      _currentTree = _workdayTree;
    } else if (widget.sessionType == 'weekly_review') {
      _currentTree = _weeklyReviewTree;
    } else {
      _currentTree = _nightlyTree;
    }

    _routineProvider = context.read<RoutineProvider>();
    if (!_routineProvider.isPlayingAmbient) {
      _routineProvider.toggleAmbientAudio();
    }
  }

  void _fetchInitialMessage() {
    // Pre-fetch the message for the very first node
    _fetchMessageForNode('start');
  }

  void _fetchMessageForNode(String nodeId) {
    // 'done_dynamic' keeps its own static, locally-interpolated message (see
    // build()) rather than an AI-generated one, since it substitutes the
    // user's actual typed intention via '[INTENTION]' — something the AI
    // prompt has no way to know.
    if (nodeId == 'done_dynamic') return;

    final cosmicMirror = context.read<CosmicMirrorService>();

    if (nodeId == 'legend_dynamic') {
      // The daily-reset cycle (RoutineProvider's history rollover) writes
      // each closed-out day into habit.history keyed by date, but this used
      // to only look at today's live isCompleted state -- so a "Weekly
      // Review" legend was really just a review of today. Aggregate the
      // last 7 days (today's live state + history for the prior 6) instead.
      final now = DateTime.now();
      final habitsDone = <String>[];
      final habitsMissed = <String>[];
      for (final habit in _routineProvider.habits.values) {
        int completedCount = habit.isCompleted ? 1 : 0;
        int trackedCount = 1;
        for (int i = 1; i < 7; i++) {
          final day = now.subtract(Duration(days: i));
          final key = day.toIso8601String().substring(0, 10);
          final wasCompleted = habit.history[key];
          if (wasCompleted != null) {
            trackedCount++;
            if (wasCompleted) completedCount++;
          }
        }
        if (completedCount >= (trackedCount / 2).ceil()) {
          habitsDone.add(habit.title);
        } else {
          habitsMissed.add(habit.title);
        }
      }
      setState(() {
        _messageFuture = cosmicMirror.generateWeeklyLegend(
          habitsDone,
          habitsMissed,
        );
      });
      return;
    }

    if (nodeId.endsWith('_dynamic')) {
      // This triggers the FutureBuilder to update
      setState(
        () => _messageFuture = cosmicMirror.generateCoachingMessage(nodeId),
      );
    }
  }

  @override
  void dispose() {
    _hypnoticAudioPlayer.dispose();
    if (_routineProvider.isPlayingAmbient) {
      _routineProvider.stopAmbientAudio();
    }
    _noteController.dispose();
    super.dispose();
  }

  void _advanceNode(String nextId) {
    HapticFeedback.lightImpact();
    if (nextId == 'exit') {
      _handleExit();
      return;
    }
    setState(() {
      _currentNodeId = nextId;
      _fetchMessageForNode(nextId);
    });
  }

  Future<void> _submitNote() async {
    HapticFeedback.heavyImpact();
    final noteText = _noteController.text.trim();

    if (noteText.isNotEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      final moodToSave = _selectedMood; // Capture mood at time of submission
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('coaching_notes')
              .add({
                // Slice it to max 2000 chars to guarantee it passes our strict Firestore rules
                'text': noteText.substring(0, min(noteText.length, 2000)),
                'createdAt': FieldValue.serverTimestamp(),
                'mood': ?moodToSave,
              });
        } catch (e) {
          debugPrint('Error saving coaching note: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Cosmic Interference: Failed to save your reflection.",
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      }
    }

    _noteController.clear();
    setState(() => _selectedMood = null); // Reset mood after submission
    _advanceNode('done_dynamic');
  }

  @override
  Widget build(BuildContext context) {
    final currentNode = _currentTree[_currentNodeId]!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. STUNNING BACKGROUND
            Positioned.fill(
              child: Image.asset(
                'assets/images/deep_nebula.png', // Ensure you have a nice space background here
                fit: BoxFit.cover,
              ).animate().fade(duration: 2.seconds),
            ),

            // 2. DARK OVERLAY FOR READABILITY
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),

            // 3. EXIT BUTTON
            Positioned(
              top: 50,
              left: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _handleExit,
              ).animate().fade(duration: 2.seconds, curve: Curves.easeOut),
            ),

            // 4. TITLE
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child:
                    Text(
                          '${widget.sessionType.toUpperCase()} COACHING',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 3.0,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                        .animate()
                        .fade(duration: 2.seconds, curve: Curves.easeOut)
                        .slideY(
                          begin: -0.5,
                          duration: 2.seconds,
                          curve: Curves.easeOut,
                        ),
              ),
            ),

            // 5. INTERACTIVE BOTTOM SECTION
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: 40.0,
                  left: 24.0,
                  right: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- FAIRY AVATAR ---
                    Align(
                      alignment: Alignment.center,
                      child:
                          Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: OrbitTokens.teal.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 5,
                                    ),
                                    BoxShadow(
                                      color: OrbitTokens.teal.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 80,
                                      spreadRadius: 20,
                                    ),
                                  ],
                                ),
                                child: Image.asset(
                                  'assets/images/fairy_avatar_flip.png',
                                ),
                              )
                              .animate(onPlay: (c) => c.repeat(reverse: true))
                              .moveY(
                                begin: -35,
                                end: -15,
                                duration: 3.seconds,
                                curve: Curves.easeInOut,
                              ),
                    ),
                    // --- CHAT BUBBLE ---
                    // SizedBox with negative height is invalid (BoxConstraints h >= 0).
                    // Use Transform.translate to achieve the same visual overlap without
                    // violating layout constraints.
                    Transform.translate(
                      offset: const Offset(0, -10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: OrbitTokens.teal.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Cosmica',
                                  style: TextStyle(
                                    color: OrbitTokens.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if ((_currentNodeId.endsWith('_dynamic') ||
                                        _currentNodeId == 'legend_dynamic') &&
                                    _currentNodeId != 'done_dynamic')
                                  FutureBuilder<String>(
                                    future: _messageFuture,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              color: OrbitTokens.teal,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      }
                                      final message =
                                          snapshot.data ??
                                          'The cosmos is silent...';
                                      return Text(
                                        message,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      );
                                    },
                                  )
                                else
                                  Text(
                                        currentNode.displayMessage.replaceAll(
                                          '[INTENTION]',
                                          _routineProvider.dailyIntention ??
                                              'master your day',
                                        ),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                      .animate()
                                      .fade(duration: 400.ms)
                                      .moveY(begin: 10, end: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- DYNAMIC OPTIONS OR INPUT ---
                    if (currentNode.isInput)
                      ...[
                            // --- MOOD SELECTOR ---
                            Text(
                              'How are you feeling? (optional)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMoodIcon(
                                  'Energized',
                                  Icons.local_fire_department_rounded,
                                ),
                                _buildMoodIcon(
                                  'Focused',
                                  Icons.center_focus_strong_rounded,
                                ),
                                _buildMoodIcon(
                                  'Calm',
                                  Icons.self_improvement_rounded,
                                ),
                                _buildMoodIcon(
                                  'Tired',
                                  Icons.battery_alert_rounded,
                                ),
                                _buildMoodIcon('Stressed', Icons.storm_rounded),
                              ],
                            ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
                            const SizedBox(height: 20),
                            // --- TEXT INPUT FIELD ---
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _selectedMood != null
                                      ? OrbitTokens.teal.withValues(
                                          alpha: 0.5,
                                        )
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: TextField(
                                controller: _noteController,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 3,
                                decoration: InputDecoration(
                                  // Mood is a purely optional tag on the note
                                  // (_submitNote() already writes it as
                                  // nullable) — it must never block sending,
                                  // only offer it.
                                  hintText: 'Type your reflection here...',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                  border: InputBorder.none,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      Icons.send_rounded,
                                      color: _noteController.text.isNotEmpty
                                          ? OrbitTokens.teal
                                          : Colors.white24,
                                    ),
                                    onPressed: _noteController.text.isNotEmpty
                                        ? _submitNote
                                        : null,
                                  ),
                                ),
                                onChanged: (text) => setState(
                                  () {},
                                ), // Rebuild to check button state
                              ),
                            ),
                          ]
                          .animate(interval: 100.ms)
                          .fade()
                          .scale(begin: const Offset(0.95, 0.95))
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: currentNode.options.map((option) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: OrbitTokens.surface
                                    .withValues(alpha: 0.6),

                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: () => _advanceNode(option.nextNodeId),
                              child: Text(
                                option.text,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ).animate().fade(duration: 400.ms).slideY(begin: 0.5);
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodIcon(String mood, IconData icon) {
    final isSelected = _selectedMood == mood;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedMood = mood);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? OrbitTokens.teal.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isSelected ? OrbitTokens.teal : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? OrbitTokens.teal : Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
