import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges to OrbitLiveActivityManager (iOS, ActivityKit) via a raw
/// MethodChannel -- iOS only, no-ops everywhere else (including iOS <16.1,
/// which the native side itself gates). Represents "today's routine
/// session," not a permanent fixture: RoutineProvider starts it on the
/// first habit completion of the day and ends it once the day's due habits
/// are all complete or at the next daily reset.
class LiveActivityService {
  static const _channel = MethodChannel('com.orbitroutine.orbit/live_activity');

  /// Starts the Activity, or updates it in place if one is already running
  /// (the native side handles that distinction) -- callers never need to
  /// know which case applies.
  static Future<void> start({
    required int completedCount,
    required int totalCount,
    required int streak,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('start', {
        'completedCount': completedCount,
        'totalCount': totalCount,
        'streak': streak,
      });
    } catch (e) {
      debugPrint('LiveActivityService.start failed: $e');
    }
  }

  static Future<void> end() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('end');
    } catch (e) {
      debugPrint('LiveActivityService.end failed: $e');
    }
  }
}
