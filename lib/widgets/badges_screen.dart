import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/routine_provider.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();

    // Define available badges dynamically based on the RoutineProvider state
    final List<Map<String, dynamic>> badges = [
      {
        'title': 'Avid Reader',
        'description': 'Read 3 wisdom letters in a single day.',
        'icon': Icons.menu_book_rounded,
        'isUnlocked': routineProvider.unlockedReaderBadge,
        'color': const Color(0xFF00E5FF), // laserCyan
      },
      {
        'title': 'Fairy Whisperer',
        'description': 'Found the secret AI Fairy easter egg.',
        'icon': Icons.auto_awesome,
        'isUnlocked': routineProvider.unlockedFairyBadge,
        'color': const Color(0xFFFF4081), // Neon Pink
      },
      {
        'title': 'Ignition',
        'description': 'Achieved a 7-day routine completion streak.',
        'icon': Icons.local_fire_department_rounded,
        'isUnlocked': routineProvider.longestStreak >= 7,
        'color': const Color(0xFFFF9100), // Orange
      },
      {
        'title': 'Orbit Achieved',
        'description': 'Achieved a 30-day routine completion streak.',
        'icon': Icons.whatshot_rounded,
        'isUnlocked': routineProvider.longestStreak >= 30,
        'color': const Color(0xFFFF3D00), // Deep Orange
      },
      {
        'title': 'Centurion',
        'description': 'Completed 100 daily habits total.',
        'icon': Icons.military_tech_rounded,
        'isUnlocked': routineProvider.totalHabitsCompleted >= 100,
        'color': const Color(0xFFFFD700), // Gold
      },
      {
        'title': 'Level 10 Commander',
        'description': 'Reached Level 10 via habit XP.',
        'icon': Icons.shield_rounded,
        'isUnlocked': routineProvider.currentLevel >= 10,
        'color': const Color(0xFF6B1DFF), // Purple
      },
      {
        'title': 'Perfectionist',
        'description': 'Kept a single habit at a 100% completion rate for 14+ days.',
        'icon': Icons.workspace_premium_rounded,
        'isUnlocked': routineProvider.habits.values.any(
          (h) => h.totalDays >= 14 && h.completedDays == h.totalDays,
        ),
        'color': const Color(0xFF33E6D8), // Teal
      },
      {
        'title': 'Perfect Week',
        'description': 'Completed 100% of your habits every day for 7 days straight.',
        'icon': Icons.emoji_events_rounded,
        'isUnlocked': routineProvider.weeklyProgress.length == 7 &&
            routineProvider.weeklyProgress.every((p) => p >= 1.0),
        'color': const Color(0xFFFFD700), // Gold
      },
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF1F1235), // Deep space violet
              Color(0xFF0F2027), // Deep space blue/black
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SCREEN HEADER ---
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 20.0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Badge Collection",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // --- BADGE GRID ---
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 40,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85, // Tweak this to adjust card height
                  ),
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    final badge = badges[index];
                    return _BadgeCard(
                      title: badge['title'],
                      description: badge['description'],
                      icon: badge['icon'],
                      isUnlocked: badge['isUnlocked'],
                      color: badge['color'],
                      index: index,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isUnlocked;
  final Color color;
  final int index;

  const _BadgeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    required this.color,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isUnlocked
                ? color.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnlocked
                  ? color.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isUnlocked ? icon : Icons.lock_rounded,
                color: isUnlocked ? color : Colors.white24,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isUnlocked ? Colors.white : Colors.white54,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Add a gentle, staggered floating animation only for unlocked badges
    if (isUnlocked) {
      return card
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: -4,
            end: 4,
            duration: 2500.ms,
            delay: (index * 200).ms, // Staggered start offset
            curve: Curves.easeInOut,
          );
    }

    return card;
  }
}
