// Real unit tests for pure logic added this session — this file used to be
// the default Flutter template stub (fully commented out, referencing a
// package:orbit/main.dart that doesn't exist in this project), which meant
// `flutter test` failed to even load before reaching any other test.

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/providers/atmosphere_provider.dart';
import 'package:orbit_app/services/export_service.dart';
import 'package:orbit_app/models/habit.dart';

void main() {
  group('AtmosphereProvider.auraForHabitCompletion', () {
    test('returns deepNebula when bouncing back from a skip', () {
      expect(
        AtmosphereProvider.auraForHabitCompletion(streak: 5, skippedCount: 1),
        OrbitAura.deepNebula,
      );
    });

    test('returns nova for a 7+ day streak with no skips', () {
      expect(
        AtmosphereProvider.auraForHabitCompletion(streak: 7, skippedCount: 0),
        OrbitAura.nova,
      );
    });

    test('returns dawn for a fresh start', () {
      expect(
        AtmosphereProvider.auraForHabitCompletion(streak: 1, skippedCount: 0),
        OrbitAura.dawn,
      );
    });

    test('returns voidSpace for a steady mid-range streak', () {
      expect(
        AtmosphereProvider.auraForHabitCompletion(streak: 4, skippedCount: 0),
        OrbitAura.voidSpace,
      );
    });

    test('a skip takes priority over an otherwise-high streak', () {
      expect(
        AtmosphereProvider.auraForHabitCompletion(streak: 30, skippedCount: 2),
        OrbitAura.deepNebula,
      );
    });
  });

  group('Habit.activeDays / isActiveOn', () {
    Habit makeHabit({List<bool>? activeDays}) => Habit(
      id: '1',
      title: 'Test',
      routineType: 'Morning',
      iconCodePoint: 0,
      color: 0,
      completedDays: 0,
      totalDays: 0,
      activeDays: activeDays,
    );

    test('defaults to every day when not specified', () {
      final habit = makeHabit();
      expect(habit.activeDays, List.filled(7, true));
      // 2026-07-20 is a Monday.
      expect(habit.isActiveOn(DateTime(2026, 7, 20)), isTrue);
      expect(habit.isActiveOn(DateTime(2026, 7, 26)), isTrue); // Sunday
    });

    test('respects a Mon/Wed/Fri schedule', () {
      final habit = makeHabit(
        activeDays: [true, false, true, false, true, false, false],
      );
      expect(habit.isActiveOn(DateTime(2026, 7, 20)), isTrue); // Monday
      expect(habit.isActiveOn(DateTime(2026, 7, 21)), isFalse); // Tuesday
      expect(habit.isActiveOn(DateTime(2026, 7, 22)), isTrue); // Wednesday
      expect(habit.isActiveOn(DateTime(2026, 7, 25)), isFalse); // Saturday
    });

    test('falls back to every day for a malformed (wrong-length) value', () {
      final habit = makeHabit(activeDays: [true, false]);
      expect(habit.activeDays, List.filled(7, true));
    });

    test('fromMap parses a stored schedule, and defaults when absent', () {
      final withSchedule = Habit.fromMap('1', {
        'title': 'Gym',
        'routine': 'Morning',
        'activeDays': [true, false, true, false, true, false, false],
      });
      expect(withSchedule.activeDays[0], isTrue);
      expect(withSchedule.activeDays[1], isFalse);

      final legacyHabit = Habit.fromMap('2', {
        'title': 'Old habit, no schedule field',
        'routine': 'Morning',
      });
      expect(legacyHabit.activeDays, List.filled(7, true));
    });

    test('toMap round-trips activeDays', () {
      final habit = makeHabit(
        activeDays: [false, true, false, true, false, true, false],
      );
      final restored = Habit.fromMap('1', habit.toMap());
      expect(restored.activeDays, habit.activeDays);
    });
  });

  group('ExportService CSV builders', () {
    test('buildHistoryCsv produces a header-only CSV with no history', () {
      final habit = Habit(
        id: '1',
        title: 'Test',
        routineType: 'Morning',
        iconCodePoint: 0,
        color: 0,
        completedDays: 0,
        totalDays: 0,
      );
      final csv = ExportService.buildHistoryCsv([habit]);
      expect(csv.trim(), 'Habit,Routine,Date,Completed');
    });

    test('buildHistoryCsv sorts rows chronologically and escapes commas', () {
      final habit = Habit(
        id: '1',
        title: 'Read, Reflect',
        routineType: 'Night',
        iconCodePoint: 0,
        color: 0,
        completedDays: 2,
        totalDays: 2,
        history: {'2026-07-02': true, '2026-07-01': false},
      );
      final csv = ExportService.buildHistoryCsv([habit]);
      final lines = csv.trim().split('\n');
      expect(lines[0], 'Habit,Routine,Date,Completed');
      expect(lines[1], '"Read, Reflect",Night,2026-07-01,No');
      expect(lines[2], '"Read, Reflect",Night,2026-07-02,Yes');
    });

    test('buildMoodCsv sorts by date', () {
      final csv = ExportService.buildMoodCsv({
        '2026-07-02': {'mood': 'Calm', 'note': 'Good day'},
        '2026-07-01': {'mood': 'Tired', 'note': ''},
      });
      final lines = csv.trim().split('\n');
      expect(lines[0], 'Date,Mood,Note');
      expect(lines[1], '2026-07-01,Tired,');
      expect(lines[2], '2026-07-02,Calm,Good day');
    });

    test('buildIntentionsCsv sorts by date', () {
      final csv = ExportService.buildIntentionsCsv({
        '2026-07-02': 'Focus on breathing',
        '2026-07-01': 'Ship the feature',
      });
      final lines = csv.trim().split('\n');
      expect(lines[0], 'Date,Intention');
      expect(lines[1], '2026-07-01,Ship the feature');
      expect(lines[2], '2026-07-02,Focus on breathing');
    });
  });
}
