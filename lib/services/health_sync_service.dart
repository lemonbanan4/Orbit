import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Wraps the `health` plugin (Android Health Connect / iOS HealthKit) for
/// the two metrics Orbit auto-completes habits from -- steps and workout
/// minutes. Progress is read-only from Orbit's perspective: nothing here
/// ever writes back to Health Connect/HealthKit.
class HealthSyncService {
  static final Health _health = Health();
  static bool _configured = false;

  // WORKOUT (not EXERCISE_TIME) for workout minutes -- EXERCISE_TIME maps to
  // Apple's watch-only "exercise minutes" quantity on iOS and has no Health
  // Connect equivalent at all on Android (absent from the plugin's
  // mapToType, so a query for it throws a null-assertion crash there).
  // WORKOUT (ExerciseSessionRecord / HKWorkoutType) exists on both
  // platforms; we derive minutes from each session's dateFrom/dateTo below.
  //
  // DISTANCE_DELTA and TOTAL_CALORIES_BURNED are requested (read-only)
  // alongside WORKOUT even though Orbit only cares about session duration --
  // verified on-device that the health plugin's WORKOUT read unconditionally
  // enriches every session with distance/calorie/step sub-queries to build a
  // summary (see health_plugin's Android HealthDataReader.handleWorkoutData),
  // and each sub-query throws SecurityException without its own read
  // permission granted. See AndroidManifest.xml's matching permissions.
  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.WORKOUT,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Android-only: Health Connect is a separate installable component:
  /// on iOS, HealthKit is part of the OS so this always returns true there.
  static Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return true;
    await _ensureConfigured();
    final status = await _health.getHealthConnectSdkStatus();
    return status == HealthConnectSdkStatus.sdkAvailable;
  }

  /// Deep-links out to the Play Store listing for Health Connect. Only
  /// meaningful when [isAvailable] returned false on Android.
  static Future<void> installHealthConnect() async {
    if (!Platform.isAndroid) return;
    await _health.installHealthConnect();
  }

  static Future<bool> hasPermissions() async {
    await _ensureConfigured();
    return await _health.hasPermissions(_types) ?? false;
  }

  static Future<bool> requestAuthorization() async {
    await _ensureConfigured();
    try {
      return await _health.requestAuthorization(_types);
    } catch (e) {
      debugPrint('HealthSyncService.requestAuthorization failed: $e');
      return false;
    }
  }

  /// Today's cumulative step count (midnight to now), or null if the read
  /// failed (permission revoked, Health Connect uninstalled mid-session,
  /// etc.) -- callers should treat null as "leave existing progress alone,"
  /// not "0 steps."
  ///
  /// Sums raw STEPS records rather than using the plugin's
  /// getTotalStepsInInterval (Health Connect's AGGREGATE_STEP_COUNT path) --
  /// verified on-device that the aggregate query can return 0 for an
  /// interval that a raw record read confirms has real data in it. Summing
  /// records directly sidesteps whatever that aggregation-index quirk is.
  static Future<int?> getTodaySteps() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: midnight,
        endTime: now,
      );
      num total = 0;
      for (final p in points) {
        final v = p.value;
        if (v is NumericHealthValue) total += v.numericValue;
      }
      return total.round();
    } catch (e) {
      debugPrint('HealthSyncService.getTodaySteps failed: $e');
      return null;
    }
  }

  /// Today's cumulative workout minutes, derived from each WORKOUT
  /// session's dateFrom/dateTo (clamped to the query window, so a session
  /// spanning midnight doesn't get double-counted into yesterday's total).
  /// Null on read failure, same contract as [getTodaySteps].
  static Future<int?> getTodayWorkoutMinutes() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: midnight,
        endTime: now,
      );
      num totalMinutes = 0;
      for (final p in points) {
        final from = p.dateFrom.isBefore(midnight) ? midnight : p.dateFrom;
        final to = p.dateTo.isAfter(now) ? now : p.dateTo;
        if (to.isAfter(from)) {
          totalMinutes += to.difference(from).inMinutes;
        }
      }
      return totalMinutes.round();
    } catch (e) {
      debugPrint('HealthSyncService.getTodayWorkoutMinutes failed: $e');
      return null;
    }
  }

  /// Today's value for a Habit.healthMetric ('steps' | 'workout_minutes').
  static Future<int?> getTodayValue(String metric) {
    switch (metric) {
      case 'steps':
        return getTodaySteps();
      case 'workout_minutes':
        return getTodayWorkoutMinutes();
      default:
        return Future.value(null);
    }
  }
}
