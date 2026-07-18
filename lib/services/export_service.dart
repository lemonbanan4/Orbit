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
      for (final entry in habit.history.entries) {
        rows.add([
          habit.title,
          habit.routineType,
          entry.key,
          entry.value ? 'Yes' : 'No',
        ]);
      }
    }
    rows.sort((a, b) => a[2].compareTo(b[2]));

    final buffer = StringBuffer()..writeln('Habit,Routine,Date,Completed');
    for (final row in rows) {
      buffer.writeln(row.map(_escapeCsvField).join(','));
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
