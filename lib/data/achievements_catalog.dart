import 'package:flutter/material.dart';
import '../providers/routine_provider.dart';

/// Single source of truth for achievement metadata and unlock conditions.
///
/// Previously this existed as three separate, drifting copies: a dead
/// Firestore 'achievements' array (initialized to [] at signup and never
/// written to by anything, so every achievement always read as locked), an
/// unreachable widgets/badges_screen.dart with its own correct-but-orphaned
/// unlock logic, and a fourth divergent metadata map inline in
/// profile_screen.dart. This consolidates them into one place both
/// AchievementsScreen and ProfileScreen read from.
const Map<String, Map<String, dynamic>> achievementsCatalog = {
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
  'Centurion': {
    'title': 'Centurion',
    'description': 'Completed 100 daily habits total.',
    'icon': Icons.military_tech_rounded,
    'color': Colors.amber,
  },
  'Level_10_Commander': {
    'title': 'Level 10 Commander',
    'description': 'Reached Level 10 via habit XP.',
    'icon': Icons.shield_rounded,
    'color': Colors.deepPurpleAccent,
  },
  'Avid_Reader': {
    'title': 'Avid Reader',
    'description': 'Read 3 wisdom letters in a single day.',
    'icon': Icons.menu_book_rounded,
    'color': Colors.tealAccent,
  },
  'Fairy_Whisperer': {
    'title': 'Fairy Whisperer',
    'description': 'Found the secret AI Fairy easter egg.',
    'icon': Icons.auto_awesome,
    'color': Colors.pinkAccent,
  },
  'Perfectionist': {
    'title': 'Perfectionist',
    'description':
        'Kept a single habit at a 100% completion rate for 14+ days.',
    'icon': Icons.workspace_premium_rounded,
    'color': Colors.tealAccent,
  },
  'Perfect_Week': {
    'title': 'Perfect Week',
    'description': 'Completed 100% of your habits every day for 7 days straight.',
    'icon': Icons.emoji_events_rounded,
    'color': Colors.amber,
  },
};

Set<String> computeEarnedAchievements(RoutineProvider routineProvider) {
  final earned = <String>{};
  if (routineProvider.longestStreak >= 7) earned.add('7_Day_Streak');
  if (routineProvider.longestStreak >= 30) earned.add('30_Day_Streak');
  if (routineProvider.longestStreak >= 100) earned.add('100_Day_Streak');
  if (routineProvider.totalHabitsCompleted >= 100) earned.add('Centurion');
  if (routineProvider.currentLevel >= 10) earned.add('Level_10_Commander');
  if (routineProvider.unlockedReaderBadge) earned.add('Avid_Reader');
  if (routineProvider.unlockedFairyBadge) earned.add('Fairy_Whisperer');
  if (routineProvider.habits.values.any(
    (h) => h.totalDays >= 14 && h.completedDays == h.totalDays,
  )) {
    earned.add('Perfectionist');
  }
  if (routineProvider.weeklyProgress.length == 7 &&
      routineProvider.weeklyProgress.every((p) => p >= 1.0)) {
    earned.add('Perfect_Week');
  }
  return earned;
}
