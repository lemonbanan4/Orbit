import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/routine_alarm.dart';
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
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
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
    required DateTimeComponents matchDateTimeComponents,
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
    String habitTitle,
    Duration delay,
  ) async {
    final int notificationId = habitTitle.hashCode;
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
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '{"screen": "dashboard"}',
      );
    } catch (e) {
      debugPrint(
        'Could not schedule reattempt reminder (Permission Denied): $e',
      );
    }
  }

  static int _getOffsetForRoutine(String routineType) {
    switch (routineType) {
      case 'Morning':
        return 100;
      case 'Afternoon':
        return 150;
      case 'Work':
        return 200;
      case 'Night':
        return 300;
      default:
        return 400;
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
