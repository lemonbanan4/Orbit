import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/habit.dart';

class ExportService {
  /// Long-format CSV — one row per (habit, tracked day) — built from
  /// Habit.history, which RoutineProvider populates during the daily
  /// reset cycle. Sorted by date so the export reads chronologically.
  static String buildHistoryCsv(Iterable<Habit> habits) {
    final rows = <List<String>>[];
    for (final habit in habits) {
      // Target/Unit/Archived reflect the habit's *current* metadata, not a
      // per-day snapshot -- history only ever stored a completion bool per
      // day, not the actual quantity reached on past days for count-based
      // habits, so that historical detail was never collected and can't be
      // reconstructed here. Still better than a "complete data export"
      // silently omitting whether a habit even used quantity tracking, or
      // whether it's currently paused, at all.
      for (final entry in habit.history.entries) {
        rows.add([
          habit.title,
          habit.routineType,
          entry.key,
          entry.value ? 'Yes' : 'No',
          habit.targetCount?.toString() ?? '',
          habit.unit ?? '',
          habit.isArchived ? 'Yes' : 'No',
          habit.healthMetric ?? '',
          habit.healthTarget?.toString() ?? '',
        ]);
      }
    }
    rows.sort((a, b) => a[2].compareTo(b[2]));

    final buffer = StringBuffer()
      ..writeln(
        'Habit,Routine,Date,Completed,Target,Unit,Archived,HealthMetric,HealthTarget',
      );
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }

  static String buildMoodCsv(Map<String, Map<String, String>> moodHistory) {
    final dates = moodHistory.keys.toList()..sort();
    final buffer = StringBuffer()..writeln('Date,Mood,Note');
    for (final date in dates) {
      final entry = moodHistory[date]!;
      buffer.writeln(
        [date, entry['mood'] ?? '', entry['note'] ?? '']
            .map(_escapeCsvField)
            .join(','),
      );
    }
    return buffer.toString();
  }

  static String buildIntentionsCsv(Map<String, String> intentionHistory) {
    final dates = intentionHistory.keys.toList()..sort();
    final buffer = StringBuffer()..writeln('Date,Intention');
    for (final date in dates) {
      buffer.writeln(
        [date, intentionHistory[date] ?? ''].map(_escapeCsvField).join(','),
      );
    }
    return buffer.toString();
  }

  static String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  static Future<File> writeCsvToTempFile(String csv, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    return file.writeAsString(csv);
  }
}
