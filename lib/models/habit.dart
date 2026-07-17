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
    Map<String, bool>? history,
  }) : history = history ?? {};

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
      history: data['history'] is Map
          ? Map<String, bool>.from(
              (data['history'] as Map).map(
                (k, v) => MapEntry(k.toString(), v == true),
              ),
            )
          : {},
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
      'history': history,
    };
  }
}
