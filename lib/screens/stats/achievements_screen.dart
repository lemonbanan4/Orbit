import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../widgets/common/achievement_card.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  // Pre-defined list of all possible achievements
  final Map<String, Map<String, dynamic>> _allAchievements = const {
    '7_Day_Streak': {
      'title': '7 Day Streak',
      'description': 'Maintained a streak for 7 consecutive days.',
      'icon': Icons.local_fire_department_rounded,
      'color': Colors.orange,
    },
    '30_Day_Streak': {
      'title': '30 Day Streak',
      'description': 'Maintained a streak for 30 consecutive days.',
      'icon': Icons.whatshot_rounded,
      'color': Colors.redAccent,
    },
    '100_Day_Streak': {
      'title': '100 Day Streak',
      'description': 'Maintained a streak for 100 consecutive days.',
      'icon': Icons.diamond_rounded,
      'color': Colors.cyan,
    },
  };

  late ConfettiController _confettiController;
  Set<String> _seenAchievements = {};
  final Set<String> _sessionNewAchievements = {};
  bool _isLoaded = false;
  late AudioPlayer _bgmPlayer;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _bgmPlayer = AudioPlayer();
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _bgmPlayer.play(AssetSource('audio/lunar_breeze.mp3'),
        volume: 0.3); // Subtle ambient volume
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
    _bgmPlayer.stop();
    _bgmPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: !_isLoaded || user == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        !snapshot.data!.exists) {
                      return const Center(
                          child: Text('Could not load achievements.',
                              style: TextStyle(color: Colors.grey)));
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    final earnedAchievements =
                        (data?['achievements'] as List<dynamic>?)
                                ?.cast<String>() ??
                            [];

                    // Find newly unlocked achievements that haven't been seen yet
                    final newAchievements = earnedAchievements
                        .where((a) => !_seenAchievements.contains(a))
                        .toList();

                    if (newAchievements.isNotEmpty) {
                      // Track locally so we can animate them, and update seen state without triggering a rebuild!
                      _sessionNewAchievements.addAll(newAchievements);
                      _seenAchievements.addAll(newAchievements);

                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (mounted) {
                          _confettiController.play();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList(
                              'seen_achievements', _seenAchievements.toList());
                        }
                      });
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio:
                            0.75, // Giving a bit more vertical room for the "Share" button
                      ),
                      itemCount: _allAchievements.length,
                      itemBuilder: (context, index) {
                        final key = _allAchievements.keys.elementAt(index);
                        final achievement = _allAchievements[key]!;
                        final isEarned = earnedAchievements.contains(key);
                        final isNewlyUnlocked =
                            _sessionNewAchievements.contains(key);

                        return AchievementCard(
                          achievementKey: key,
                          achievement: achievement,
                          isEarned: isEarned,
                          isNewlyUnlocked: isNewlyUnlocked,
                        );
                      },
                    );
                  },
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
                      Colors.orange,
                      Colors.blue,
                      Colors.pink,
                      Colors.green,
                      Colors.purple
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
