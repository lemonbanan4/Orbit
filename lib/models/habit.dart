import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String title;
  final String routineType;
  final int iconCodePoint;
  final int color;
  int completedDays;
  int totalDays;
  int order;
  int skippedCount;
  bool isCompleted;
  final String time;
  final bool isGoal;
  Map<String, bool> history;
  // One of StellarPlanetVariant's names ('fitness'/'mind'/'productivity'/
  // 'growth'/'core') — drives per-category Focus Journey chapter progress.
  // Null for habits created before this field existed or left uncategorized.
  final String? category;
  // 7 entries, index 0=Monday..6=Sunday (same convention as
  // RoutineAlarm.activeDays) — which days this habit is actually due.
  // Defaults to every day, so habits created before this field existed
  // behave exactly as before.
  final List<bool> activeDays;
  // Null = a simple checkbox habit (the original/default behavior).
  // Non-null = a count-based habit ("Drink 8 glasses of water") with this
  // as the daily target; [unit] labels what's being counted ("glasses").
  // [currentCount] is today's live progress, reset to 0 alongside
  // isCompleted at the daily rollover; isCompleted itself stays the single
  // source of truth everywhere else (streaks, stats, Focus Journeys) --
  // it's just driven by currentCount >= targetCount for these habits
  // instead of a direct tap.
  final int? targetCount;
  final String? unit;
  int currentCount;
  // Paused, not deleted -- keeps all its stats/history but drops out of
  // the daily checklist and stops being counted as a "miss" once archived,
  // until unarchived. Not fully invisible everywhere by design: a genuine
  // completion earned before archiving still counts (e.g. the same-day
  // progress chart in statistics_screen.dart), and categoryCompletions()
  // still sums an archived habit's lifetime completedDays toward its Focus
  // Journey category -- pausing forgives future misses, it doesn't erase
  // real past effort. Defaults to false so existing habits are unaffected.
  bool isArchived;

  Habit({
    required this.id,
    required this.title,
    required this.routineType,
    required this.iconCodePoint,
    required this.color,
    required this.completedDays,
    required this.totalDays,
    this.order = 0,
    this.skippedCount = 0,
    this.isCompleted = false,
    this.time = '00:00',
    this.isGoal = false,
    this.category,
    this.targetCount,
    this.unit,
    this.currentCount = 0,
    this.isArchived = false,
    List<bool>? activeDays,
    Map<String, bool>? history,
  }) : history = history ?? {},
       activeDays = (activeDays != null && activeDays.length == 7)
           ? activeDays
           : List.filled(7, true);

  /// True if this habit is scheduled to run on [date] (defaults to today).
  bool isActiveOn([DateTime? date]) {
    return activeDays[(date ?? DateTime.now()).weekday - 1];
  }

  /// This habit's own consecutive-day completion streak, walking backward
  /// through [history]. Purely derived (no separately persisted counter,
  /// so it can't drift from the underlying data) -- unlike the app-wide
  /// streak, there's no per-habit counter anywhere else to reuse.
  ///
  /// Today only ever adds to the streak if already completed; an
  /// incomplete-but-still-due-today habit doesn't break it, matching how
  /// the app-wide streak isn't broken mid-day either (only at the daily
  /// reset). A day this habit wasn't due on (per [activeDays]) is skipped
  /// rather than breaking the streak -- _checkDailyReset only ever writes
  /// a history entry for a day the habit was due-or-completed, so a
  /// missing entry on a due day means the walk has run past when the
  /// habit started existing, which should also stop the count.
  int computeCurrentStreak() {
    int streak = isCompleted ? 1 : 0;
    DateTime day = DateTime.now().subtract(const Duration(days: 1));
    while (streak < 3650) {
      final key = day.toIso8601String().substring(0, 10);
      final entry = history[key];
      if (entry == null) {
        if (!isActiveOn(day)) {
          day = day.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      if (!entry) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  factory Habit.fromSnapshot(DocumentSnapshot doc, {bool isCompleted = false}) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Habit.fromMap(doc.id, data, isCompleted: isCompleted);
  }

  factory Habit.fromMap(
    String docId,
    Map<String, dynamic> data, {
    bool isCompleted = false,
  }) {
    // --- BULLETPROOF ICON PARSER ---
    // Handles both the Ints from the Custom Sheet and the Strings from the AI Genie
    int parsedIcon = 0xe24a; // Default to 'Explore' icon
    if (data['iconCodePoint'] != null) {
      parsedIcon = data['iconCodePoint'] is int
          ? data['iconCodePoint']
          : int.tryParse(data['iconCodePoint'].toString()) ?? 0xe24a;
    } else if (data['icon'] != null) {
      if (data['icon'] is String) {
        final Map<String, int> iconMap = {
          'Explore': 0xe24a,
          'Fitness': 0xe2c4,
          'Book': 0xe0ef,
          'Mind': 0xe577,
          'Sun': 0xe6e8,
          'Moon': 0xe466,
          'Work': 0xe6f2,
          'Heart': 0xe25b,
        };
        parsedIcon = iconMap[data['icon']] ?? 0xe24a;
      } else if (data['icon'] is int) {
        parsedIcon = data['icon'];
      }
    }

    // --- BULLETPROOF COLOR PARSER ---
    int parsedColor = 0xFF00E5FF; // Default Cyan
    if (data['color'] != null) {
      parsedColor = data['color'] is int
          ? data['color']
          : int.tryParse(data['color'].toString()) ?? 0xFF00E5FF;
    }

    return Habit(
      id: docId,
      title: data['title']?.toString() ?? 'Unknown Habit',
      routineType:
          data['routine']?.toString() ?? data['path']?.toString() ?? 'Morning',
      iconCodePoint: parsedIcon,
      color: parsedColor,
      completedDays: data['completedDays'] is int ? data['completedDays'] : 0,
      // Older habits were seeded with a vestigial "21-day goal" constant
      // (7 for AI-constellation habits) that nothing ever consumed as a
      // goal — RoutineProvider now treats this as a running "days
      // tracked" tally, so 0 is the only sane default/fallback.
      totalDays: data['totalDays'] is int ? data['totalDays'] : 0,
      order: data['order'] is int ? data['order'] : 0,
      skippedCount: data['skippedCount'] is int ? data['skippedCount'] : 0,
      time: data['time']?.toString() ?? '00:00',
      isCompleted: isCompleted,
      isGoal: data['isGoal'] == true,
      category: data['category']?.toString(),
      history: data['history'] is Map
          ? Map<String, bool>.from(
              (data['history'] as Map).map(
                (k, v) => MapEntry(k.toString(), v == true),
              ),
            )
          : {},
      activeDays: data['activeDays'] is List && data['activeDays'].length == 7
          ? (data['activeDays'] as List).map((v) => v == true).toList()
          : null,
      targetCount: data['targetCount'] is int ? data['targetCount'] : null,
      unit: data['unit']?.toString(),
      currentCount: data['currentCount'] is int ? data['currentCount'] : 0,
      isArchived: data['isArchived'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'routine': routineType,
      'iconCodePoint': iconCodePoint,
      'color': color,
      'completedDays': completedDays,
      'totalDays': totalDays,
      'order': order,
      'skippedCount': skippedCount,
      'time': time,
      'isCompleted': isCompleted,
      'isGoal': isGoal,
      'history': history,
      'activeDays': activeDays,
      'isArchived': isArchived,
      if (category != null) 'category': category,
      if (targetCount != null) 'targetCount': targetCount,
      if (unit != null) 'unit': unit,
      if (targetCount != null) 'currentCount': currentCount,
    };
  }
}
