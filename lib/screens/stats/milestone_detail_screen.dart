import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/share_milestone_button.dart';
import '../../widgets/common/premium_glass_card.dart';
import '../../widgets/common/glow_orb.dart';

class MilestoneDetailScreen extends StatefulWidget {
  final String stepTitle;
  final bool isUnlocked;

  const MilestoneDetailScreen({
    super.key,
    required this.stepTitle,
    this.isUnlocked = true,
  });

  @override
  State<MilestoneDetailScreen> createState() => _MilestoneDetailScreenState();
}

class _MilestoneDetailScreenState extends State<MilestoneDetailScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isSaving = false;
  Future<Map<String, dynamic>>? _milestoneDataFuture;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isUnlocked) {
      _milestoneDataFuture = _fetchMilestoneData();
    }
    _fetchUserStreak();
  }

  Future<void> _fetchUserStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          _currentStreak = doc.data()?['streakCount'] as int? ?? 0;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _fetchMilestoneData() async {
    try {
      // Using GetOptions to ensure we capture failure correctly if offline
      final doc = await FirebaseFirestore.instance
          .collection('milestones')
          .doc(widget.stepTitle)
          .get(const GetOptions(source: Source.serverAndCache));

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final audioUrl = data['audioUrl'] as String?;

        if (audioUrl != null && audioUrl.isNotEmpty) {
          await _player.setUrl(audioUrl);
          _player.playerStateStream.listen((state) {
            if (state.processingState == ProcessingState.completed) {
              _completeMilestone();
            }
          });
        }
        return data;
      }
      return {'content': 'Content for this milestone is coming soon!'};
    } catch (e) {
      debugPrint('Error fetching milestone data: $e');
      // Return explicit offline error state
      return {'error': 'offline'};
    }
  }

  Future<void> _completeMilestone() async {
    if (_isSaving || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        final userDoc = await userRef.get();
        final data = userDoc.data() ?? {};
        final lastDateTimestamp = data['lastCompletionDate'] as Timestamp?;
        int currentStreak = data['streakCount'] as int? ?? 0;
        int longestStreak = data['longestStreak'] as int? ?? 0;

        final completedMilestones =
            (data['completedMilestones'] as List<dynamic>?)?.cast<String>() ??
                [];
        completedMilestones.add(widget.stepTitle);

        final List<String> allSteps = [
          'Day 1: Getting Started',
          'Day 2: Finding Rhythm',
          'Day 3: Building Momentum',
          'Day 4: Pushing Through',
          'Day 5: The Final Stretch',
        ];

        String nextMilestone = 'Journey Complete! 🎉';
        for (String step in allSteps) {
          if (!completedMilestones.contains(step)) {
            nextMilestone = step;
            break;
          }
        }

        final now = DateTime.now();
        final todayUtc = DateTime.utc(now.year, now.month, now.day);

        if (lastDateTimestamp != null) {
          final lastDate = lastDateTimestamp.toDate();
          final lastDayUtc = DateTime.utc(
            lastDate.year,
            lastDate.month,
            lastDate.day,
          );
          final difference = todayUtc.difference(lastDayUtc).inDays;
          final absoluteDifferenceHours = now.difference(lastDate).inHours;

          if (difference == 1 ||
              (difference == 2 && absoluteDifferenceHours <= 48)) {
            currentStreak += 1;
          } else if (difference > 1) {
            currentStreak = 1;
          }
        } else {
          currentStreak = 1;
        }

        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        List<String> newAchievements = [];
        if (currentStreak == 7) newAchievements.add('7_Day_Streak');
        if (currentStreak == 30) newAchievements.add('30_Day_Streak');
        if (currentStreak == 100) newAchievements.add('100_Day_Streak');

        final updates = <String, dynamic>{
          'completedMilestones': FieldValue.arrayUnion([widget.stepTitle]),
          'unlockedMilestones': FieldValue.arrayUnion([
            widget.stepTitle,
            nextMilestone,
          ]),
          'lastCompletionDate': FieldValue.serverTimestamp(),
          'streakCount': currentStreak,
          'longestStreak': longestStreak,
        };

        if (newAchievements.isNotEmpty) {
          updates['achievements'] = FieldValue.arrayUnion(newAchievements);
        }

        await userRef.update(updates);

        try {
          // Use the same keys that OrbitWidget.kt reads on Android and
          // OrbitWidget reads on iOS — 'widget_streak' / 'widget_intention'.
          // 'HabsWidgetProvider' was never registered in AndroidManifest.xml
          // and caused ClassNotFoundException; use 'OrbitWidget' instead.
          await HomeWidget.saveWidgetData<String>(
            'widget_streak',
            currentStreak.toString(),
          );
          await HomeWidget.saveWidgetData<String>(
            'widget_intention',
            nextMilestone,
          );
          await HomeWidget.updateWidget(
            androidName: 'OrbitWidget',
            iOSName: 'OrbitWidget',
          );
        } catch (e) {
          debugPrint('Error updating home widget: $e');
        }

        if (newAchievements.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎉 Achievement Unlocked: ${newAchievements.first.replaceAll('_', ' ')}!',
              ),
              backgroundColor: Colors.amber,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save progress. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Widget _buildOfflineState() {
    return Center(
      child: PremiumGlassCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white54),
            const SizedBox(height: 24),
            const Text(
              'Signal Lost',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'We couldn\'t connect to the network to download this milestone. Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _milestoneDataFuture = _fetchMilestoneData();
                  });
                },
              ),
            ),
          ],
        ),
      )
          .animate()
          .fade()
          .scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack),
    );
  }

  Widget _buildLockedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: const PremiumGlassCard(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 64, color: Colors.white54),
              SizedBox(height: 24),
              Text(
                'Milestone Locked',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Complete previous milestones to unlock this content and continue your journey.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        )
            .animate()
            .fade()
            .scaleXY(begin: 0.9, end: 1.0, curve: Curves.easeOutBack),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color bgColor = Color(0xFF050112);
    const Color orbColor1 = Color(0xFF00E5FF);
    const Color orbColor2 = Color(0xFF7000FF);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Journey Milestone',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // --- 3D POP: BACKGROUND GLOW ORBS ---
          const GlowOrb(
            color: Color(0x4D00E5FF),
            size: 400,
            top: -100,
            right: -100,
          ),
          const GlowOrb(
            color: Color(0x4D7000FF),
            size: 350,
            bottom: -50,
            left: -100,
          ),

          SafeArea(
            child: !widget.isUnlocked
                ? _buildLockedState()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: orbColor1.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: orbColor1.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.star_rounded,
                            color: orbColor1,
                            size: 40,
                          ),
                        ).animate().scaleXY(
                              begin: 0.8,
                              end: 1.0,
                              curve: Curves.easeOutBack,
                            ),
                        const SizedBox(height: 24),
                        Text(
                          widget.stepTitle,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ).animate().fadeIn().slideX(begin: -0.1),
                        const SizedBox(height: 24),
                        if (_milestoneDataFuture != null)
                          Expanded(
                            child: FutureBuilder<Map<String, dynamic>>(
                              future: _milestoneDataFuture,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: orbColor1,
                                    ),
                                  );
                                }

                                final data = snapshot.data ?? {};
                                if (data.containsKey('error')) {
                                  return _buildOfflineState();
                                }

                                final content =
                                    data['content'] as String? ?? '';
                                final audioUrl = data['audioUrl'] as String?;

                                return ListView(
                                  padding: const EdgeInsets.only(bottom: 40.0),
                                  physics: const BouncingScrollPhysics(),
                                  children: [
                                    PremiumGlassCard(
                                      child: Html(
                                        data: content,
                                        style: {
                                          "body": Style(
                                            fontSize: FontSize(18.0),
                                            color: Colors.white70,
                                            lineHeight: const LineHeight(
                                              1.6,
                                            ),
                                            margin: Margins.zero,
                                          ),
                                          "strong": Style(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          "h1": Style(color: Colors.white),
                                          "h2": Style(color: Colors.white),
                                          "h3": Style(color: Colors.white),
                                          "a": Style(color: orbColor1),
                                          "img": Style(
                                            display: Display.block,
                                            width: Width(100, Unit.percent),
                                            margin: Margins.symmetric(
                                              vertical: 16.0,
                                            ),
                                          ),
                                        },
                                      ),
                                    )
                                        .animate()
                                        .fade(delay: 200.ms)
                                        .slideY(begin: 0.1),
                                    if (audioUrl != null &&
                                        audioUrl.isNotEmpty) ...[
                                      const SizedBox(height: 24),
                                      _buildAudioPlayer(orbColor1),
                                    ],
                                    const SizedBox(height: 40),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: orbColor1,
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 18,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed: _isSaving
                                            ? null
                                            : _completeMilestone,
                                        child: _isSaving
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.black,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text(
                                                'Complete Action',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    )
                                        .animate()
                                        .fade(delay: 400.ms)
                                        .slideY(begin: 0.2),
                                    const SizedBox(height: 16),
                                    Center(
                                      child: ShareMilestoneButton(
                                        milestoneTitle: widget.stepTitle,
                                        streakCount: _currentStreak,
                                      ),
                                    )
                                        .animate()
                                        .fade(delay: 500.ms)
                                        .slideY(begin: 0.2),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(Color accentColor) {
    return PremiumGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final processingState = playerState?.processingState;
              final playing = playerState?.playing;

              if (processingState == ProcessingState.loading ||
                  processingState == ProcessingState.buffering) {
                return Container(
                  margin: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: accentColor),
                );
              } else if (playing != true) {
                return IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  iconSize: 72.0,
                  color: accentColor,
                  onPressed: _player.play,
                );
              } else if (processingState != ProcessingState.completed) {
                return IconButton(
                  icon: const Icon(Icons.pause_circle_filled_rounded),
                  iconSize: 72.0,
                  color: accentColor,
                  onPressed: _player.pause,
                );
              } else {
                return IconButton(
                  icon: const Icon(Icons.replay_circle_filled_rounded),
                  iconSize: 72.0,
                  color: accentColor,
                  onPressed: () => _player.seek(Duration.zero),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _player.duration ?? Duration.zero;

              double maxVal = duration.inMilliseconds.toDouble();
              if (maxVal <= 0.0) maxVal = 1.0;
              double currentVal = position.inMilliseconds.toDouble().clamp(
                    0.0,
                    maxVal,
                  );

              String formatDuration(Duration d) {
                final minutes =
                    d.inMinutes.remainder(60).toString().padLeft(2, '0');
                final seconds =
                    d.inSeconds.remainder(60).toString().padLeft(2, '0');
                return '$minutes:$seconds';
              }

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accentColor,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                      thumbColor: Colors.white,
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: currentVal,
                      max: maxVal,
                      onChanged: (value) {
                        _player.seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          formatDuration(duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ).animate().fade(delay: 300.ms).slideY(begin: 0.1);
  }
}
