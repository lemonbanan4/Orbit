import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/common/stat_box.dart';
import '../../services/share_service.dart';
import '../../extensions/widget_to_image.dart';
import 'package:confetti/confetti.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;
  String? _currentGoal;
  bool _isLoadingData = true;
  String? _errorMessage;
  late ConfettiController _confettiController;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _audioPlayer = AudioPlayer();
    _fetchUserData();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (mounted) {
          setState(() {
            _currentGoal = doc.data()?['currentGoal'] as String?;
            _isLoadingData = false;
            _errorMessage = null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingData = false;
            _errorMessage = "Failed to load recap data. Please try again.";
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = "You must be logged in to view your recap.";
        });
      }
    }
  }

  Future<void> _shareRecap() async {
    setState(() => _isSharing = true);
    _confettiController.play();
    try {
      await _audioPlayer.setAsset('assets/audio/orbit_chime.wav');
      _audioPlayer.play();

      // Fun vibration pattern to pair with the chime and explosion
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 150, 100, 250]);
      }
    } catch (e) {
      debugPrint('Failed to play audio: $e');
    }
    try {
      final file = await ShareService.captureOffscreenWidget(
        _buildOffscreenShareWidget(),
        'weekly_recap',
      );

      if (mounted && file != null) {
        ShareService.showShareBottomSheet(
          context: context,
          imageFile: file,
          shareText:
              "I just crushed my week in Orbit! 🚀 Can you beat my streak?",
        );
      }
    } catch (e) {
      debugPrint('Error generating share image: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // --- STATIC RENDER COMPONENTS FOR OFFSCREEN SHARING ---
  // These don't contain any Entry Animations, ensuring the screenshot
  // captures them fully opaque and instantly!
  Widget _buildStaticStatBox(
      String title, String value, IconData icon, Color color) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.1), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildOffscreenShareWidget() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: 1080,
        height: 1080,
        color: const Color(0xFF050112),
        alignment: Alignment.center,
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(64),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C3258), Color(0xFF1A1F36)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(48),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
              width: 4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Orbit Weekly Recap',
                style: TextStyle(
                    color: Colors.white54, fontSize: 24, letterSpacing: 4),
              ),
              const SizedBox(height: 40),
              const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFF00E5FF), size: 96),
              const SizedBox(height: 40),
              const Text(
                'Outstanding Week!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 48),
              if (_currentGoal != null && _currentGoal!.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.track_changes_rounded,
                          color: Colors.amber, size: 32),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          'Goal: $_currentGoal',
                          style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                              fontSize: 28),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStaticStatBox('XP Earned', '+450', Icons.stars_rounded,
                      Colors.cyanAccent),
                  _buildStaticStatBox('Habits Done', '24',
                      Icons.check_circle_rounded, Colors.greenAccent),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStaticStatBox('Longest Streak', '7 Days',
                      Icons.local_fire_department_rounded, Colors.orangeAccent),
                ],
              ),
              const SizedBox(height: 64),
              const Text(
                'orbit.app',
                style: TextStyle(
                    color: Colors.white38,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1F36), // Deep space background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _isLoadingData
                ? const Center(
                    key: ValueKey('loading'),
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  )
                : _errorMessage != null
                    ? Center(
                        key: const ValueKey('error'),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isLoadingData = true;
                                  _errorMessage = null;
                                });
                                _fetchUserData();
                              },
                              icon: const Icon(Icons.refresh_rounded,
                                  color: Color(0xFF00E5FF)),
                              label: const Text('Retry',
                                  style: TextStyle(color: Color(0xFF00E5FF))),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        key: const ValueKey('content'),
                        children: [
                          Expanded(
                            child: Center(
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2C3258),
                                      Color(0xFF1A1F36)
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF00E5FF,
                                    ).withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF00E5FF,
                                      ).withValues(alpha: 0.2),
                                      blurRadius: 30,
                                      spreadRadius: -5,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Orbit Weekly Recap',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 16,
                                        letterSpacing: 2,
                                      ),
                                    ).animate().fade().slideY(begin: -0.5),
                                    const SizedBox(height: 24),
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Color(0xFF00E5FF),
                                      size: 64,
                                    )
                                        .animate(
                                            onPlay: (c) =>
                                                c.repeat(reverse: true))
                                        .scaleXY(
                                          begin: 0.9,
                                          end: 1.1,
                                          duration: 1.seconds,
                                        ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Outstanding Week!',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        height: 1.1,
                                      ),
                                    )
                                        .animate()
                                        .fade(delay: 200.ms)
                                        .scaleXY(curve: Curves.easeOutBack),
                                    const SizedBox(height: 40),

                                    if (_currentGoal != null &&
                                        _currentGoal!.isNotEmpty) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.amber.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.track_changes_rounded,
                                              color: Colors.amber,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                'Goal: $_currentGoal',
                                                style: const TextStyle(
                                                  color: Colors.amber,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                          .animate()
                                          .fade(delay: 300.ms)
                                          .slideY(begin: 0.2),
                                      const SizedBox(height: 24),
                                    ],

                                    // Stats Grid
                                    const Row(
                                      children: [
                                        Expanded(
                                          child: StatBox(
                                            title: 'XP Earned',
                                            value: '+450',
                                            icon: Icons.stars_rounded,
                                            delay: 400,
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        Expanded(
                                          child: StatBox(
                                            title: 'Habits Done',
                                            value: '24',
                                            icon: Icons.check_circle_rounded,
                                            delay: 500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Row(
                                      children: [
                                        Expanded(
                                          child: StatBox(
                                            title: 'Longest Streak',
                                            value: '7 Days',
                                            icon: Icons
                                                .local_fire_department_rounded,
                                            color: Colors.orange,
                                            delay: 600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    const Text(
                                      'orbit.app',
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ).animate().fade(delay: 800.ms),
                                  ],
                                ).toRepaintBoundary(_globalKey),
                              ),
                            ),
                          ),

                          // Share Button
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E5FF),
                                  foregroundColor: const Color(0xFF1A1F36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: _isSharing
                                    ? null
                                    : () {
                                        HapticFeedback.heavyImpact();
                                        _shareRecap();
                                      },
                                icon: _isSharing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Color(0xFF1A1F36),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.ios_share_rounded),
                                label: Text(
                                  _isSharing ? 'Generating...' : 'Share Recap',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ).animate().slideY(
                                begin: 1.0,
                                curve: Curves.easeOutCubic,
                                delay: 800.ms,
                              ),
                        ],
                      ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 40,
              gravity: 0.15,
              colors: const [
                Color(0xFF00E5FF),
                Color(0xFF7000FF),
                Colors.white,
                Colors.orangeAccent,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
