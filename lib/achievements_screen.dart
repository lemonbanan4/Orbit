import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import 'widgets/common/base_orbit_screen.dart';
import 'providers/routine_provider.dart';
import 'data/achievements_catalog.dart';
import 'services/share_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final Map<String, Map<String, dynamic>> _allAchievements =
      achievementsCatalog;

  late ConfettiController _confettiController;
  Set<String> _seenAchievements = {};
  final Set<String> _sessionNewAchievements = {};
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _loadSeenAchievements();
  }

  Future<void> _loadSeenAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _seenAchievements =
          (prefs.getStringList('seen_achievements') ?? []).toSet();
      _isLoaded = true;
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const Color orbColor1 = Color(0xFF00E5FF);
    final routineProvider = context.watch<RoutineProvider>();

    return BaseOrbitScreen(
      title: 'Achievements',
      body: !_isLoaded || user == null
          ? const Center(child: CircularProgressIndicator(color: orbColor1))
          : Stack(
              children: [
                Builder(
                  builder: (context) {
                    final earnedAchievements =
                        computeEarnedAchievements(routineProvider);
                    final newAchievements = earnedAchievements
                        .where((a) => !_seenAchievements.contains(a))
                        .toList();

                    if (newAchievements.isNotEmpty) {
                      _sessionNewAchievements.addAll(newAchievements);
                      _seenAchievements.addAll(newAchievements);

                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (mounted) {
                          // Settings > "Enable Confetti" never actually
                          // gated anything -- this fired unconditionally.
                          if (routineProvider.confettiEnabled) {
                            _confettiController.play();
                          }
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList(
                            'seen_achievements',
                            _seenAchievements.toList(),
                          );
                        }
                      });
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(24),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.70,
                      ),
                      itemCount: _allAchievements.length,
                      itemBuilder: (context, index) {
                        final key = _allAchievements.keys.elementAt(index);
                        final achievement = _allAchievements[key]!;
                        final isEarned = earnedAchievements.contains(key);
                        final isNewlyUnlocked =
                            _sessionNewAchievements.contains(key);

                        return _AchievementCard(
                          achievementKey: key,
                          achievement: achievement,
                          isEarned: isEarned,
                          isNewlyUnlocked: isNewlyUnlocked,
                        );
                      },
                    );
                  },
                ),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConfettiWidget(
                      confettiController: _confettiController,
                      blastDirectionality: BlastDirectionality.explosive,
                      emissionFrequency: 0.05,
                      numberOfParticles: 40,
                      gravity: 0.15,
                      colors: const [
                        Colors.orange,
                        Colors.cyan,
                        Colors.purpleAccent,
                        Colors.yellow,
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _AchievementCard extends StatefulWidget {
  final String achievementKey;
  final Map<String, dynamic> achievement;
  final bool isEarned;
  final bool isNewlyUnlocked;

  const _AchievementCard({
    required this.achievementKey,
    required this.achievement,
    required this.isEarned,
    required this.isNewlyUnlocked,
  });

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareAchievement() async {
    if (!widget.isEarned || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      // ShareService.captureWidget is the same RepaintBoundary-capture
      // logic this used to hand-roll — now shared with the (previously
      // unused) richer share sheet below instead of duplicated here.
      final file = await ShareService.captureWidget(
        _globalKey,
        'achievement_${widget.achievementKey}',
      );
      if (file != null && mounted) _showShareBottomSheet(file);
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showShareBottomSheet(File imageFile) {
    final String shareText =
        "I just unlocked the '${widget.achievement['title']}' badge in Orbit! 🚀 Can you beat my streak?";
    // Was a plain native share before — ShareService's sheet was fully
    // built (native share + post-to-X + copy text + save to Photos) but
    // sat unused while this screen only exposed the first option.
    ShareService.showShareBottomSheet(
      context: context,
      imageFile: imageFile,
      shareText: shareText,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTap: widget.isEarned
          ? () {
              HapticFeedback.lightImpact();
              _shareAchievement();
            }
          : null,
      child: RepaintBoundary(
        key: _globalKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                // Blend the color over an opaque dark color so the exported PNG isn't transparent!
                color: widget.isEarned
                    ? Color.alphaBlend(
                        widget.achievement['color'].withOpacity(0.15),
                        const Color(0xFF13002B),
                      )
                    : const Color(0xFF13002B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.isEarned
                      ? widget.achievement['color'].withOpacity(0.5)
                      : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) {
                      Widget iconWidget = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.isEarned
                              ? widget.achievement['color'].withValues(
                                  alpha: 0.2,
                                )
                              : Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.achievement['icon'],
                          color: widget.isEarned
                              ? widget.achievement['color']
                              : Colors.white24,
                          size: 36,
                        ),
                      );
                      Animate animatedIcon = iconWidget
                          .animate(target: widget.isEarned ? 1 : 0)
                          .scaleXY(
                            end: 1.15,
                            duration: 600.ms,
                            curve: Curves.easeOutBack,
                          );
                      if (widget.isEarned) {
                        return animatedIcon
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .shimmer(duration: 2000.ms, color: Colors.white70);
                      }
                      return animatedIcon;
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.achievement['title'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.isEarned ? Colors.white : Colors.white54,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.achievement['description'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.isEarned ? Colors.white70 : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                  if (widget.isEarned) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          size: 14,
                          color: widget.achievement['color'],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Share',
                          style: TextStyle(
                            color: widget.achievement['color'],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_isSharing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF050112).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    Animate animatedCard = card
        .animate(target: widget.isEarned ? 1 : 0)
        .fade(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
    if (widget.isNewlyUnlocked) {
      animatedCard = animatedCard
          .flipH(
            begin: -1,
            end: 0,
            duration: 800.ms,
            curve: Curves.easeOutBack,
            delay: 200.ms,
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .boxShadow(
            begin: const BoxShadow(
              color: Colors.transparent,
              blurRadius: 0,
              spreadRadius: 0,
            ),
            end: BoxShadow(
              color: widget.achievement['color'].withOpacity(0.7),
              blurRadius: 24,
              spreadRadius: 8,
            ),
            duration: 1200.ms,
            curve: Curves.easeInOut,
          );
    }
    return animatedCard;
  }
}
