import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// One week of an AI-generated 4-week habit roadmap (a "Constellation").
/// [habitId] is null until this week has actually been activated as a real
/// habit in the user's routine -- see
/// RoutineProvider._checkConstellationProgress.
class ConstellationWeek {
  final int week; // 1-4
  final String habitTitle;
  final String icon; // AI category string: 'Mind'/'Fitness'/'Explore'/'Book'
  final String routine; // 'Morning'/'Work'/'Night'
  final String description;
  String? habitId;

  ConstellationWeek({
    required this.week,
    required this.habitTitle,
    required this.icon,
    required this.routine,
    required this.description,
    this.habitId,
  });

  factory ConstellationWeek.fromMap(Map<String, dynamic> data) {
    return ConstellationWeek(
      week: data['week'] is int ? data['week'] : 1,
      habitTitle: data['habitTitle']?.toString() ?? 'Habit',
      icon: data['icon']?.toString() ?? 'Explore',
      routine: data['routine']?.toString() ?? 'Morning',
      description: data['description']?.toString() ?? '',
      habitId: data['habitId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'week': week,
    'habitTitle': habitTitle,
    'icon': icon,
    'routine': routine,
    'description': description,
    if (habitId != null) 'habitId': habitId,
  };
}

/// A persisted AI-generated 4-week habit roadmap (from the Constellation
/// Builder / "Routine Genie"). Unlike a one-shot habit dump, weeks unlock one
/// at a time -- 7 calendar days apart -- so the AI's escalating-difficulty
/// design is preserved instead of thrown away the instant the user accepts.
class Constellation {
  final String id;
  final String goal;
  final List<ConstellationWeek> weeks; // always length 4, sorted by week
  int currentWeek; // 1-4: the most recently activated week
  String status; // 'active' | 'completed' | 'abandoned'
  final DateTime createdAt;

  Constellation({
    required this.id,
    required this.goal,
    required this.weeks,
    required this.currentWeek,
    required this.status,
    required this.createdAt,
  });

  factory Constellation.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Constellation.fromMap(doc.id, data);
  }

  factory Constellation.fromMap(String id, Map<String, dynamic> data) {
    final rawWeeks = data['habits'];
    final weeks = rawWeeks is List
        ? rawWeeks
              .map(
                (w) =>
                    ConstellationWeek.fromMap(Map<String, dynamic>.from(w)),
              )
              .toList()
        : <ConstellationWeek>[];
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.now();
    return Constellation(
      id: id,
      goal: data['goal']?.toString() ?? '',
      weeks: weeks,
      currentWeek: data['currentWeek'] is int ? data['currentWeek'] : 1,
      status: data['status']?.toString() ?? 'active',
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'goal': goal,
    'habits': weeks.map((w) => w.toMap()).toList(),
    'currentWeek': currentWeek,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  /// Which week number SHOULD be unlocked right now, purely time-based (7
  /// calendar days per week) -- deliberately NOT tied to completion/streak
  /// state, so this never touches the fragile daily-streak machinery.
  int get unlockedWeek {
    final daysElapsed = DateTime.now().difference(createdAt).inDays;
    final week = 1 + (daysElapsed / 7).floor();
    return week.clamp(1, 4);
  }

  DateTime unlockDateForWeek(int week) =>
      createdAt.add(Duration(days: (week - 1) * 7));
}

/// Shared icon/colour theme for the 4 AI-assigned week categories, so the
/// Constellation Builder (immediate week-1 preview) and RoutineProvider
/// (activating weeks 2-4 later) never drift out of sync.
class ConstellationCategoryTheme {
  static int iconCodePointFor(String category) {
    switch (category) {
      case 'Fitness':
        return Icons.fitness_center_rounded.codePoint;
      case 'Mind':
        return Icons.self_improvement_rounded.codePoint;
      case 'Book':
      case 'Structure':
        return Icons.menu_book_rounded.codePoint;
      case 'Explore':
        return Icons.explore_rounded.codePoint;
      default:
        return Icons.star_rounded.codePoint;
    }
  }

  static int colorFor(String category) {
    switch (category) {
      case 'Fitness':
        return 0xFFFF8A4C; // OrbitTokens.morning
      case 'Mind':
        return 0xFFA66CFF; // OrbitTokens.violet
      case 'Book':
      case 'Structure':
        return 0xFF33E6D8; // OrbitTokens.teal
      case 'Explore':
        return 0xFFF2C879; // OrbitTokens.gold
      default:
        return 0xFF3D5CFF;
    }
  }
}
