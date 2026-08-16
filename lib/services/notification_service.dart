import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/routine_alarm.dart';
import '../models/habit.dart';
import '../main.dart'; // Import to access navigatorKey
import '../screens/settings/notifications_screen.dart';
import '../screens/navigation/main_navigation_screen.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  @visibleForTesting
  static FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Reusable iOS configuration constants
  static const DarwinNotificationDetails _defaultIOSDetails =
      DarwinNotificationDetails(
        sound: 'orbit_chime.wav',
        presentBanner: true,
        presentList: true,
        presentBadge: true,
        presentSound: true,
      );

  static Future<void> init() async {
    // Initialize timezone data so tz.local doesn't throw a LateInitializationError
    tz_data.initializeTimeZones();
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
    } catch (e) {
      debugPrint('Could not set local timezone: $e');
    }

    // 1. Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    // 2. iOS Settings
    //
    // Deliberately false: this .initialize() call runs at app boot (see
    // main()), before the user has even reached the login/onboarding
    // screen. requestAlertPermission: true here fires the real iOS system
    // permission dialog immediately -- and since iOS only ever shows that
    // dialog once per install, it "uses up" the ask on a context-free
    // cold-start prompt, permanently turning the deliberate, contextual
    // soft-ask (showNotificationPrePrompt -> checkAndRequestPermissions,
    // called from MainNavigationScreen post-login) into a no-op. The real
    // request now happens only from that contextual flow.
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    // 3. Combine Settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    // 4. Initialize properly without the hacky "dynamic" bypass
    await notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // This fires when the user taps the notification!
        if (navigatorKey.currentState != null) {
          final payload = response.payload;

          // Route to the dashboard if payload specifies it (e.g. Second Chance reminder)
          if (payload != null && payload.contains('dashboard')) {
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => const MainNavigationScreen(),
              ),
              (route) => false,
            );
          } else {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          }
        }
      },
    );
  }

  static Future<void> deleteOldChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    if (androidImplementation != null) {
      // Pass the exact string IDs of the old channels you want to remove
      await androidImplementation.deleteNotificationChannel(
        channelId: 'routine_channel',
      );
      await androidImplementation.deleteNotificationChannel(
        channelId: 'daily_channel',
      );
    }
  }

  static Future<bool> requestExactAlarmsPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    final bool? granted = await androidImplementation
        ?.requestExactAlarmsPermission();

    if (granted == false) {
      debugPrint(
        'Exact alarms permission denied. Notifications will fall back to inexact scheduling.',
      );
    }
    return granted ?? false;
  }

  // Helper to centralize configuration and implement fallback if exact alarms are denied
  static Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    // Null means one-off (no repeat). Passing a value like
    // DateTimeComponents.time makes the plugin treat this as a daily
    // recurring notification -- only pass one for genuinely repeating
    // reminders (routine alarms), never for a single delayed nudge.
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    try {
      await notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    } catch (e) {
      debugPrint(
        'Exact alarm scheduling failed (likely permission denied), retrying inexact: $e',
      );
      try {
        await notificationsPlugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
          payload: payload,
        );
      } catch (fallbackError) {
        debugPrint('Fallback inexact scheduling also failed: $fallbackError');
      }
    }
  }

  static Future<void> cancelAlarms(String routineType) async {
    int offset = _getOffsetForRoutine(routineType);
    // Cancel up to 10 alarms (70 IDs) per routine to be safe and clear out old ones
    for (int i = 0; i < 70; i++) {
      await notificationsPlugin.cancel(id: offset + i);
    }
  }

  /// Cancels a specific scheduled alarm by its exact ID
  static Future<void> cancelAlarm(int id) async {
    await notificationsPlugin.cancel(id: id);
  }

  static Future<void> scheduleRoutineAlarms(
    String routineType,
    List<RoutineAlarm> alarms,
  ) async {
    await cancelAlarms(routineType);
    int offset = _getOffsetForRoutine(routineType);

    for (int i = 0; i < alarms.length; i++) {
      final alarm = alarms[i];
      final parts = alarm.time.split(':');
      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]) ?? 8;
      final minute = int.tryParse(parts[1]) ?? 0;

      for (int day = 0; day < 7; day++) {
        if (alarm.activeDays[day]) {
          final scheduledDate = _nextInstanceOfDayTime(day + 1, hour, minute);
          const details = NotificationDetails(
            android: AndroidNotificationDetails(
              'routine_channel_v2',
              'Routine Reminders',
              channelDescription: 'Reminders for your daily habits',
              groupKey: 'orbit_reminders',
              importance: Importance.max,
              priority: Priority.high,
              sound: RawResourceAndroidNotificationSound('orbit_chime'),
            ),
            iOS: _defaultIOSDetails,
          );

          try {
            await _safeZonedSchedule(
              id: offset + (i * 7) + day,
              title: '$routineType Routine',
              body:
                  "It's time to master your day! Your $routineType habits are waiting.",
              scheduledDate: scheduledDate,
              details: details,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );

            // Schedule the group summary for the exact same time
            const summaryDetails = NotificationDetails(
              android: AndroidNotificationDetails(
                'routine_channel_v2',
                'Routine Reminders',
                channelDescription: 'Reminders for your daily habits',
                groupKey: 'orbit_reminders',
                setAsGroupSummary: true,
                styleInformation: InboxStyleInformation(
                  [],
                  summaryText: 'You have pending cosmic habits!',
                ),
              ),
              iOS: _defaultIOSDetails,
            );
            await _safeZonedSchedule(
              id:
                  offset +
                  60 +
                  day, // Stays under 70, cleanly removed by cancelAlarms
              title: 'Orbit Reminders',
              body: 'Pending habits',
              scheduledDate: scheduledDate,
              details: summaryDetails,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
          } catch (e) {
            debugPrint(
              'Could not schedule exact alarm (Permission Denied): $e',
            );
          }
        }
      }
    }
  }

  // Distinct salted hash so a habit reminder's IDs never collide with
  // scheduleReattemptReminder's plain habitId.hashCode, or with the
  // routine-alarm ID blocks (100-599, see _getOffsetForRoutine). Pushed
  // well clear of both into a dedicated range; a 7-day block reserved per
  // habit (days 0-6) the same way scheduleRoutineAlarms reserves one
  // per alarm slot.
  static int _habitReminderBaseId(String habitId) {
    return 700000 + ('habit_reminder_$habitId'.hashCode.abs() % 200000) * 7;
  }

  static Future<void> cancelHabitReminder(String habitId) async {
    final baseId = _habitReminderBaseId(habitId);
    for (int day = 0; day < 7; day++) {
      await notificationsPlugin.cancel(id: baseId + day);
    }
  }

  /// Schedules (or, if disabled, cancels) [habit]'s own reminder --
  /// distinct from the routine-level alarms, this nudges for one specific
  /// habit at [habit.reminderTime] on each day in [habit.activeDays].
  static Future<void> scheduleHabitReminder(Habit habit) async {
    await cancelHabitReminder(habit.id);
    if (!habit.remindersEnabled || habit.reminderTime == null) return;

    final parts = habit.reminderTime!.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts[1]) ?? 0;
    final baseId = _habitReminderBaseId(habit.id);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'habit_reminder_channel_v1',
        'Habit Reminders',
        channelDescription: 'Reminders for individual habits',
        groupKey: 'orbit_reminders',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('orbit_chime'),
      ),
      iOS: _defaultIOSDetails,
    );

    for (int day = 0; day < 7; day++) {
      if (!habit.activeDays[day]) continue;
      final scheduledDate = _nextInstanceOfDayTime(day + 1, hour, minute);
      try {
        await _safeZonedSchedule(
          id: baseId + day,
          title: habit.title,
          body: "It's time: ${habit.title}",
          scheduledDate: scheduledDate,
          details: details,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: '{"screen": "dashboard"}',
        );
      } catch (e) {
        debugPrint('Could not schedule habit reminder for ${habit.id}: $e');
      }
    }
  }

  static Future<void> scheduleDailyReminder() async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      9, // 9:00 AM
      0,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_channel_v2',
        'Daily Reminders',
        channelDescription: 'Reminders to check in daily',
        groupKey: 'orbit_reminders',
        importance: Importance.max,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('orbit_chime'),
      ),
      iOS: _defaultIOSDetails,
    );

    try {
      await _safeZonedSchedule(
        id: 999,
        title: 'Time to Orbit 🚀',
        body: 'Your daily habits are waiting. Master your day!',
        scheduledDate: scheduledDate,
        details: details,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Could not schedule daily reminder (Permission Denied): $e');
    }
  }

  // --- Smart re-engagement nudges (v1.2) -----------------------------------
  // A rolling ladder of gentle "come back" notifications for lapsed users.
  // The whole ladder is re-scheduled (slid forward from *now*) every time the
  // user is active, so an engaged user never actually sees them -- they only
  // fire for someone who's genuinely been away for [_reEngageDayOffsets] days.
  // Fixed IDs, well clear of routine (100..570), the daily reminder (999) and
  // per-habit reminders (700000+), so they never collide with those sweeps.
  static const List<int> _reEngagementIds = [8001, 8002, 8003];
  static const List<int> _reEngageDayOffsets = [2, 4, 7];

  static Future<void> cancelReEngagementNudges() async {
    for (final id in _reEngagementIds) {
      await notificationsPlugin.cancel(id: id);
    }
  }

  /// (Re)schedules the lapsed-user nudge ladder starting from now. Call this
  /// whenever the user is active (app boot, habit completed) so it keeps
  /// sliding forward. Copy is adaptive: an at-risk streak is named on the
  /// first, gentlest nudge, and the tone stays forgiving as it escalates.
  static Future<void> scheduleReEngagementNudges({int currentStreak = 0}) async {
    await cancelReEngagementNudges();

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'reengagement_channel_v1',
        'Come Back Reminders',
        channelDescription: 'Gentle nudges when you have been away a while',
        groupKey: 'orbit_reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('orbit_chime'),
      ),
      iOS: _defaultIOSDetails,
    );

    final stages = _reEngagementCopy(currentStreak);
    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < _reEngagementIds.length; i++) {
      // 11:00 AM, [offset] days out -- a friendly, non-intrusive hour.
      tz.TZDateTime when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        11,
        0,
      ).add(Duration(days: _reEngageDayOffsets[i]));
      // Guard against a same-day-past-11am edge landing before now.
      if (when.isBefore(now)) {
        when = now.add(Duration(days: _reEngageDayOffsets[i]));
      }

      await _safeZonedSchedule(
        id: _reEngagementIds[i],
        title: stages[i].$1,
        body: stages[i].$2,
        scheduledDate: when,
        details: details,
        payload: '{"screen": "dashboard"}',
      );
    }
  }

  /// Three escalating (title, body) pairs. The first names an at-risk streak
  /// when there is one; the last is deliberately pressure-free ("fresh start").
  static List<(String, String)> _reEngagementCopy(int streak) {
    final firstBody = streak > 1
        ? 'Cosmica is keeping your orbit warm. Your $streak-day streak is '
            'still glowing — one habit keeps it alive. 🌌'
        : 'Cosmica is keeping your orbit warm. One small step today gets you '
            'back in motion. 🌌';
    return [
      ('Your orbit misses you 🌌', firstBody),
      (
        'The stars are drifting 🌠',
        "It's been a few days. Your universe is right where you left it — "
            'pick up in a single tap.',
      ),
      (
        'Ready for a fresh orbit? 🚀',
        'No pressure and no guilt — just come reset and start a clean launch. '
            "We've saved your spot among the stars.",
      ),
    ];
  }

  // --- Constellation week-unlock notifications (v1.3) ----------------------
  // Fixed IDs 9001..9004 (one per week 1..4, though week 1 never actually
  // fires -- it's activated immediately on accept), well clear of every
  // other sweep: routine alarms (100..570ish), the daily reminder (999),
  // per-habit reminders (700000+), and re-engagement nudges (8001..8003).
  static const List<int> _constellationWeekIds = [9001, 9002, 9003, 9004];

  static Future<void> cancelConstellationNotifications() async {
    for (final id in _constellationWeekIds) {
      await notificationsPlugin.cancel(id: id);
    }
  }

  /// Schedules a one-off notification for when [week] (2..4) unlocks, so the
  /// user finds out even if they never reopen the app right at the 7-day
  /// mark (RoutineProvider's own catch-up logic handles that case anyway --
  /// this is purely for discoverability). No-ops for a date already in the
  /// past.
  static Future<void> scheduleConstellationWeekUnlock({
    required int week,
    required String habitTitle,
    required DateTime unlockDate,
  }) async {
    if (week < 1 || week > 4) return;
    final scheduledTime = tz.TZDateTime.from(unlockDate, tz.local);
    if (scheduledTime.isBefore(tz.TZDateTime.now(tz.local))) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'constellation_channel_v1',
        'Constellation Progress',
        channelDescription: 'Your AI-guided roadmap unlocking a new week',
        groupKey: 'orbit_reminders',
        importance: Importance.high,
        priority: Priority.high,
        sound: RawResourceAndroidNotificationSound('orbit_chime'),
      ),
      iOS: _defaultIOSDetails,
    );

    try {
      await _safeZonedSchedule(
        id: _constellationWeekIds[week - 1],
        title: 'Week $week has begun 🌌',
        body: 'Your next star has ignited: $habitTitle',
        scheduledDate: scheduledTime,
        details: details,
        payload: '{"screen": "dashboard"}',
      );
    } catch (e) {
      debugPrint('Could not schedule constellation week $week unlock: $e');
    }
  }

  static tz.TZDateTime _nextInstanceOfDayTime(int day, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    while (scheduledDate.weekday != day) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  static Future<void> scheduleReattemptReminder(
    String habitId,
    String habitTitle,
    Duration delay,
  ) async {
    // Keyed on habit ID, not title -- titles have no uniqueness
    // constraint (preset habits especially), so two identically-named
    // habits skipped the same day used to collide on the same
    // notification ID and silently overwrite each other's reminder.
    final int notificationId = habitId.hashCode.abs();
    final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'com.orbit.reminders',
        'Orbit Reminders',
        channelDescription: 'Reminders for skipped habits',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: _defaultIOSDetails,
    );

    try {
      await _safeZonedSchedule(
        id: notificationId,
        title: 'Second Chance: $habitTitle',
        body:
            'The cosmos has aligned for another attempt. Ready to dive back in?',
        scheduledDate: scheduledTime,
        details: details,
        payload: '{"screen": "dashboard"}',
      );
    } catch (e) {
      debugPrint(
        'Could not schedule reattempt reminder (Permission Denied): $e',
      );
    }
  }

  static int _getOffsetForRoutine(String routineType) {
    // Each block must stay clear of cancelAlarms()'s 70-ID sweep (offset..
    // offset+69) and the up to ~67 IDs a maxed-out routine (8 alarms x 7
    // days, plus summary IDs at +60..+66) can actually use -- these used
    // to be only 50-100 apart, so saving Morning's alarms could silently
    // wipe Afternoon's (and Afternoon's could wipe Work's) via the blind
    // 70-ID cancel sweep landing inside the neighboring block.
    switch (routineType) {
      case 'Morning':
        return 100;
      case 'Afternoon':
        return 200;
      case 'Work':
        return 300;
      case 'Night':
        return 400;
      default:
        return 500;
    }
  }

  /// Retrieves a list of all currently scheduled and pending notifications
  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await notificationsPlugin.pendingNotificationRequests();
  }

  static Future<void> checkAndRequestPermissions(BuildContext context) async {
    PermissionStatus status = await Permission.notification.status;

    if (status.isDenied) {
      status = await Permission.notification.request();
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Notifications Disabled'),
            content: const Text(
              'To receive habit reminders, please enable notifications '
              'for Orbit in your device settings.',
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
              ),
            ],
          ),
        );
      }
    } else if (status.isGranted) {
      // Permissions are good to go!
      debugPrint("Notifications granted!");
    }
  }

  static Future<void> showNotificationPrePrompt(BuildContext context) async {
    final bool? userAgreed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Stay on track!'),
          content: const Text(
            'We\'d like to send you gentle reminders to complete your cosmic habits. '
            'You can turn these off anytime.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Not Now'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              child: const Text('Enable Notifications'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // If the user tapped "Enable Notifications" in our custom UI,
    // trigger the actual OS prompt.
    if (userAgreed == true && context.mounted) {
      await checkAndRequestPermissions(context);
      // Also request Android 12+'s exact-alarm permission here -- this was
      // previously never called anywhere, so every routine/daily/reattempt
      // reminder's exact scheduling attempt silently failed and fell back
      // to inexact (drifting within the OS's batching window) with no way
      // for the user to fix it.
      await requestExactAlarmsPermission();
    }
  }

  /// Clears all currently visible routine notifications from the device's tray
  static Future<void> clearActiveRoutineReminders() async {
    try {
      final activeNotifications = await notificationsPlugin
          .getActiveNotifications();
      for (var active in activeNotifications) {
        if (active.groupKey == 'orbit_reminders' ||
            active.title?.contains('Routine') == true ||
            active.title?.contains('Orbit Reminders') == true) {
          if (active.id != null) {
            await notificationsPlugin.cancel(id: active.id!);
          }
        }
      }
      // Always cancel the manual group summary fallback
      await notificationsPlugin.cancel(id: 0);
    } catch (e) {
      debugPrint('Failed to clear active notifications: $e');
    }
  }
}
