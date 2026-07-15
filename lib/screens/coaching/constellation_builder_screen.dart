// lib/screens/coaching/constellation_builder_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../services/ai_coach_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../services/cosmic_mirror_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/ai_fairy_bubble.dart';
import '../../theme/glass_button.dart';
import '../../widgets/common/animated_frosty_button.dart';

class ConstellationBuilderScreen extends StatefulWidget {
  const ConstellationBuilderScreen({super.key});

  @override
  State<ConstellationBuilderScreen> createState() =>
      _ConstellationBuilderScreenState();
}

class _ConstellationBuilderScreenState
    extends State<ConstellationBuilderScreen> {
  final TextEditingController _goalController = TextEditingController();
  List<Map<String, dynamic>> _constellation = [];
  bool _isLoading = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  Future<String>? _greetingFuture;
  bool _isListening = false;
  double _soundLevel = 0.0;

  @override
  void initState() {
    super.initState();
    // Fetch the dynamic greeting when the screen loads
    _greetingFuture = context
        .read<CosmicMirrorService>()
        .generateRoutineGenieGreeting();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _speech.stop(); // Safe teardown of audio lines on screen exit
    super.dispose();
  }

  void _runGenie() async {
    if (_goalController.text.isEmpty) return;

    // 🔍 DEBUG LOG 1: Verify the function actually triggers
    debugPrint("🚀 GENIE START: Goal text is: '${_goalController.text}'");

    setState(() => _isLoading = true);

    try {
      HapticFeedback.mediumImpact();

      // 🔍 DEBUG LOG 2: Firing network request
      debugPrint(
        "📡 DISPATCHING: Requesting constellation layout from AiCoachService...",
      );

      // We add a strict 15-second timeout gate. If the server hangs, this forces an exception!
      final result = await AiCoachService.generateConstellation(
        _goalController.text,
      ).timeout(const Duration(seconds: 15));

      // 🔍 DEBUG LOG 3: Data successfully returned
      debugPrint("✅ SUCCESS: Received ${result.length} nodes from AI service.");

      if (mounted) {
        setState(() {
          _constellation = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      // 🔍 DEBUG LOG 4: Catch the exact network wall
      debugPrint("💥 CRITICAL AI ERROR: Generation loop failed! Reason: $e");

      if (mounted) {
        setState(() => _isLoading = false);

        final isTimeout = e.toString().contains('TimeoutException');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isTimeout
                  ? "The cosmos is taking too long to respond. Check your internet connection!"
                  : "Cosmic Interference: $e",
            ),
            backgroundColor: Colors.redAccent,

            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _runGenie(),
            ),
          ),
        );
      }
    }
  }

  String _getPlanetAsset(String? iconType) {
    switch (iconType) {
      case 'Fitness':
        return 'assets/images/planet_fitness.png';
      case 'Mind':
        return 'assets/images/planet_mind.png';
      case 'Book':
      case 'Structure':
        return 'assets/images/planet_productivity.png';
      case 'Explore':
        return 'assets/images/planet_growth.png';
      default:
        return 'assets/images/planet_default.png';
    }
  }

  Future<void> _acceptDestiny() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _constellation.isEmpty) return;

    setState(() => _isLoading = true);
    HapticFeedback.heavyImpact();

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var habit in _constellation) {
        final habitId =
            'constellation_${habit['week']}_${DateTime.now().millisecondsSinceEpoch}';
        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('habits')
            .doc(habitId);

        batch.set(docRef, {
          'title': habit['habitTitle'],
          'description': habit['description'],
          'icon': habit['icon'],
          'completedDays': 0,
          'totalDays': 7,
          'createdAt': FieldValue.serverTimestamp(),
          'isConstellationHabit': true,
          'week': habit['week'],
        });
      }

      await batch.commit();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _constellation = [];
          _goalController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Destiny accepted! Check your active habits. 🌌"),
            backgroundColor: Color(0xFF7000FF),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Cosmic interference: $e"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _runGenie(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050112),
      body: Stack(
        children: [
          // 1. COSMIC BACKGROUND LAYER
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'assets/images/nebula_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 2. RUNTIME VIEWPORT
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _constellation.isEmpty
                      ? SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: _buildInputArea()
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.05, end: 0.0),
                        )
                      : _buildConstellationMap(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final double glowIntensity = (_soundLevel + 50).clamp(0.0, 100.0) / 50.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _isListening
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withValues(
                              alpha: (0.2 + (glowIntensity * 0.3)).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                            blurRadius: 10 + (glowIntensity * 20),
                            spreadRadius: glowIntensity * 8,
                          ),
                        ]
                      : [],
                ),
                child: IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: const Color(0xFF00E5FF),
                  ),
                  onPressed: () async {
                    if (!_isListening) {
                      final status = await Permission.microphone.request();
                      if (status != PermissionStatus.granted) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Microphone permission is required to use voice input.',
                              ),
                            ),
                          );
                        }
                        return;
                      }

                      bool available = await _speech.initialize(
                        finalTimeout: const Duration(seconds: 5),
                        onStatus: (status) {
                          // 🚀 THE FIX: Force a hard stop when the OS stops recording!
                          if (status == 'notListening' || status == 'done') {
                            if (mounted) {
                              setState(() {
                                _isListening = false;
                                _soundLevel = 0.0;
                              });
                            }
                            _speech
                                .stop(); // 🔐 Explicitly releases the hardware line lock!
                          }
                        },
                        onError: (errorNotification) {
                          if (mounted) {
                            setState(() {
                              _isListening = false;
                              _soundLevel = 0.0;
                            });
                          }
                          _speech.stop();
                        },
                      );

                      if (available) {
                        setState(() => _isListening = true);
                        _speech.listen(
                          onResult: (val) {
                            if (mounted) {
                              _goalController.text = val.recognizedWords;
                              _goalController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _goalController.text.length,
                                    ),
                                  );
                            }
                          },
                          onSoundLevelChange: (level) {
                            if (mounted) setState(() => _soundLevel = level);
                          },
                        );
                      }
                    } else {
                      // Manually stopping early if they tap the mic button again
                      setState(() {
                        _isListening = false;
                        _soundLevel = 0.0;
                      });
                      await _speech.stop();
                    }
                  },
                  tooltip: 'Voice Input',
                  iconSize: 28,
                ),
              ),
              if (_isListening)
                const Padding(
                  padding: EdgeInsets.only(top: 4.0),
                  child: Text(
                    "listening...",
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
          if (_isListening) ...[
            const SizedBox(width: 8),
            Row(
              children: List.generate(4, (index) {
                final double scale =
                    (_soundLevel + 50).clamp(0.0, 100.0) / 50.0;
                final double adjustedScale =
                    0.3 + (scale * (0.2 + (index * 0.1)));

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: 16 * adjustedScale.clamp(0.3, 2.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(width: 12),
          const Text(
            "Routine Genie",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: PremiumGlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                  width: 180,
                  height:
                      180, // Optimized asset sizing leaves room for soft keyboards
                  child: Image.asset('assets/images/fairy_avatar.png'),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.95, end: 1.05, duration: 2.seconds),

            const SizedBox(height: 16),

            // Value-listening container rebuilds cleanly when audio inputs text components down
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _goalController,
              builder: (context, value, child) {
                if (value.text.isNotEmpty) {
                  return AIFairyBubble(
                    message: '"${value.text}"',
                    isListening: _isListening,
                  );
                }
                // When input is empty, show the dynamic greeting
                return FutureBuilder<String>(
                  future: _greetingFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const AIFairyBubble(
                        message: "...",
                        isListening: true,
                      );
                    }
                    final message =
                        snapshot.data ??
                        "The cosmos is silent. What is your desire?";
                    return AIFairyBubble(
                      message: message,
                      isListening: _isListening,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "What is your ultimate objective?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _goalController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: "e.g. Master Stoicism, Run a 5k...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),

            AnimatedFrostyButton(
                  text: 'CONSTRUCT CONSTELLATION',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _runGenie,
                )
                .animate(target: _isLoading ? 0.5 : 1.0)
                .fade(begin: 0.8, end: 1.0, duration: 400.ms)
                .scaleXY(
                  begin: 0.95,
                  end: 1.0,
                  duration: 500.ms,
                  curve: Curves.easeOutBack,
                ),
            // SizedBox(
            //   width: double.infinity,
            //   child: ElevatedButton(
            //     style: ElevatedButton.styleFrom(
            //       backgroundColor: const Color(0xFF00E5FF),
            //       foregroundColor: Colors.black,
            //       padding: const EdgeInsets.symmetric(vertical: 16),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(16),
            //       ),
            //     ),
            //     onPressed: _isLoading ? null : _runGenie,
            //     child: _isLoading
            //         ? const SizedBox(
            //             width: 20,
            //             height: 20,
            //             child: CircularProgressIndicator(
            //               color: Colors.black,
            //               strokeWidth: 2,
            //             ),
            //           )
            //         : const Text(
            //             "CONSTRUCT CONSTELLATION",
            //             style: TextStyle(
            //               fontWeight: FontWeight.bold,
            //               letterSpacing: 0.5,
            //             ),
            //           ),
            //   ),
            // ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.05);
  }

  Widget _buildConstellationMap() {
    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 140),
            child: SizedBox(
              height: 800,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size.infinite,
                    painter: StarLinePainter(nodeCount: _constellation.length),
                  ),
                  ...List.generate(_constellation.length, (index) {
                    final habit = _constellation[index];
                    double top = 100.0 + (index * 140);
                    double left = index % 2 == 0 ? 50 : 200;

                    return Positioned(
                      top: top,
                      left: left,
                      child: _buildStarNode(habit, index),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 30, left: 24, right: 24),
            child: SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7000FF),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 10,
                          shadowColor: const Color(
                            0xFF7000FF,
                          ).withValues(alpha: 0.5),
                        ),
                        onPressed: _isLoading ? null : _acceptDestiny,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                "ACCEPT DESTINY",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                  color: Colors.white,
                                ),
                              ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.03, duration: 800.ms)
                      .shimmer(color: Colors.white24, duration: 2.seconds),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStarNode(Map<String, dynamic> habit, int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPlanetDetails(habit);
      },
      child: Column(
        children: [
          Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  _getPlanetAsset(habit['icon']),
                  fit: BoxFit.contain,
                ),
              )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 0.9,
                end: 1.1,
                duration: 1500.ms,
                curve: Curves.easeInOut,
              )
              .shimmer(color: Colors.white24, duration: 3.seconds),
          const SizedBox(height: 12),
          Text(
            "WEEK ${habit['week']}",
            style: const TextStyle(
              color: Color(0xFF00E5FF),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          Text(
            habit['habitTitle'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ).animate().fadeIn(delay: (200 * index).ms).slideY(begin: 0.2, end: 0),
    );
  }

  void _showPlanetDetails(Map<String, dynamic> habit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF050112).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                blurRadius: 30,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(_getPlanetAsset(habit['icon']), width: 80, height: 80)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.95, end: 1.05, duration: 2.seconds),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "PHASE ${habit['week']}",
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                habit['habitTitle'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                habit['description'],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  text: "Understood",
                  onPressed: () => Navigator.pop(context),
                ),
                // child: TextButton(
                //   onPressed: () => Navigator.pop(context),
                //   style: TextButton.styleFrom(
                //     backgroundColor: Colors.white.withValues(alpha: 0.1),
                //     padding: const EdgeInsets.symmetric(vertical: 16),
                //   ),
                //   child: const Text(
                //     "Understood",
                //     style: TextStyle(
                //       color: Colors.white,
                //       fontWeight: FontWeight.bold,
                //     ),
                //   ),
                // ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StarLinePainter extends CustomPainter {
  final int nodeCount;
  StarLinePainter({required this.nodeCount});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < nodeCount - 1; i++) {
      double x1 = i % 2 == 0 ? 80 : 230;
      double y1 = 140.0 + (i * 140);
      double x2 = (i + 1) % 2 == 0 ? 80 : 230;
      double y2 = 140.0 + ((i + 1) * 140);

      path.moveTo(x1, y1);
      path.quadraticBezierTo((x1 + x2) / 2 + 50, (y1 + y2) / 2, x2, y2);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant StarLinePainter oldDelegate) =>
      oldDelegate.nodeCount != nodeCount;
}
