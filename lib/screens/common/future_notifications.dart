import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Must be a top-level function to run independently of the app lifecycle
@pragma('vm:entry-point')
Future<void> notificationTapBackground(
    NotificationResponse notificationResponse) async {
  debugPrint(
      'Notification tapped in background/terminated state: ${notificationResponse.payload}');

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase
      .initializeApp(); // Assumes options are provided elsewhere or default

  if (notificationResponse.actionId == 'mark_complete') {
    debugPrint('Action: Mark Complete tapped in background');

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userRef =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        final userDoc = await userRef.get();
        final data = userDoc.data() ?? {};

        final lastDateTimestamp = data['lastCompletionDate'] as Timestamp?;
        int currentStreak = data['streakCount'] as int? ?? 0;
        final completedMilestones =
            (data['completedMilestones'] as List<dynamic>?)?.cast<String>() ??
                [];

        final List<String> allSteps = [
          'Day 1: Getting Started',
          'Day 2: Finding Rhythm',
          'Day 3: Building Momentum',
          'Day 4: Pushing Through',
          'Day 5: The Final Stretch'
        ];

        String currentPending = allSteps.first;
        int pendingIndex = 0;
        for (int i = 0; i < allSteps.length; i++) {
          if (!completedMilestones.contains(allSteps[i])) {
            currentPending = allSteps[i];
            pendingIndex = i;
            break;
          }
        }
        String nextMilestone = (pendingIndex + 1 < allSteps.length)
            ? allSteps[pendingIndex + 1]
            : 'Journey Complete! 🎉';

        final now = DateTime.now();
        final todayUtc = DateTime.utc(now.year, now.month, now.day);

        if (lastDateTimestamp != null) {
          final lastDate = lastDateTimestamp.toDate();
          final lastDayUtc =
              DateTime.utc(lastDate.year, lastDate.month, lastDate.day);
          final difference = todayUtc.difference(lastDayUtc).inDays;
          final absoluteDifferenceHours = now.difference(lastDate).inHours;

          if (difference == 1 ||
              (difference == 2 && absoluteDifferenceHours <= 48)) {
            currentStreak += 1;
          } else if (difference > 1) {
            currentStreak = 1;
          }
        } else {
          currentStreak = 1;
        }

        List<String> newAchievements = [];
        if (currentStreak == 7) newAchievements.add('7_Day_Streak');
        if (currentStreak == 30) newAchievements.add('30_Day_Streak');
        if (currentStreak == 100) newAchievements.add('100_Day_Streak');

        final updates = <String, dynamic>{
          'lastCompletionDate': FieldValue.serverTimestamp(),
          'streakCount': currentStreak,
          'completedMilestones': FieldValue.arrayUnion([currentPending]),
        };

        if (newAchievements.isNotEmpty) {
          updates['achievements'] = FieldValue.arrayUnion(newAchievements);
        }

        await userRef.update(updates);

        try {
          // Use the same keys that OrbitWidget.kt reads on Android and
          // OrbitWidget reads on iOS — 'widget_streak' / 'widget_intention'.
          // 'HabsWidgetProvider' was never registered in AndroidManifest.xml
          // and caused ClassNotFoundException; use 'OrbitWidget' instead.
          await HomeWidget.saveWidgetData<String>(
              'widget_streak', currentStreak.toString());
          await HomeWidget.saveWidgetData<String>(
              'widget_intention', nextMilestone);
          await HomeWidget.updateWidget(
              androidName: 'OrbitWidget', iOSName: 'OrbitWidget');
        } catch (e) {
          debugPrint('Error updating home widget: $e');
        }
      } catch (e) {
        debugPrint('Failed to update Firestore in background: $e');
      }
    }
  } else if (notificationResponse.actionId == 'snooze') {
    debugPrint('Action: Snooze tapped in background');

    tz_data.initializeTimeZones();
    final String currentTimeZone =
        (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 3,
      title: 'Snooze: Time for your journey! 🚀',
      body: 'Your path is waiting. Take a few minutes to focus now.',
      scheduledDate:
          tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
            'daily_reminder_v2', 'Daily Reminders',
            importance: Importance.max,
            priority: Priority.high,
            groupKey: 'journey_reminders',
            color: Color(0xFF00E5FF),
            sound: RawResourceAndroidNotificationSound('success_chime')),
        iOS: DarwinNotificationDetails(
            threadIdentifier: 'journey_reminders',
            categoryIdentifier: 'journey_category'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: notificationResponse.payload,
    );
  }
}

Future<void> requestNotificationPermissions(BuildContext? context) async {
  final status = await Permission.notification.request();

  if (status.isPermanentlyDenied) {
    if (context != null && context.mounted) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF0A102A),
          title: const Text('Notifications Disabled',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'To help you stay on track, Habs needs notification permissions. Please enable them in your device settings.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not Now',
                  style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('Open Settings',
                  style: TextStyle(
                      color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else {
      await openAppSettings();
    }
  }

  if (!kIsWeb && Platform.isAndroid && status.isGranted) {
    final alarmStatus = await Permission.scheduleExactAlarm.request();
    if (alarmStatus.isPermanentlyDenied) {
      // Handle exact alarm permissions here
    }
  }
}

Future<void> scheduleDailyReminder() async {
  final prefs = await SharedPreferences.getInstance();
  final int hour = prefs.getInt('reminder_hour') ?? 9; // Default to 9 AM
  final int minute = prefs.getInt('reminder_minute') ?? 0;

  final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
  tz.TZDateTime scheduledDate =
      tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }

  String activePath = 'Morning Routine';
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final interests =
          (doc.data()?['interests'] as List<dynamic>?)?.cast<String>() ?? [];
      if (interests.isNotEmpty) {
        activePath = interests.first;
      }
    } catch (e) {
      debugPrint('Failed to fetch active path for notification: $e');
    }
  }

  String? imagePath;
  try {
    final byteData = await rootBundle.load('assets/icon.png');
    final file = File('${Directory.systemTemp.path}/notification_image.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    imagePath = file.path;
  } catch (e) {
    debugPrint('Failed to load notification image: $e');
  }

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id: 0,
    title: 'Time for your journey! 🚀',
    body:
        'Your next milestone is waiting for you. Take a few minutes to focus on your path today.',
    scheduledDate: scheduledDate,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder_v2',
        'Daily Reminders',
        importance: Importance.max,
        priority: Priority.high,
        groupKey: 'journey_reminders',
        color: const Color(0xFF00E5FF),
        sound: const RawResourceAndroidNotificationSound('success_chime'),
        styleInformation: imagePath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(imagePath),
                hideExpandedLargeIcon: true,
                contentTitle: 'Time for your journey! 🚀',
                summaryText:
                    'Your next milestone is waiting for you. Take a few minutes to focus on your path today.',
              )
            : null,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction('mark_complete', 'Mark Complete'),
          AndroidNotificationAction('snooze', 'Snooze'),
        ],
      ),
      iOS: DarwinNotificationDetails(
        threadIdentifier: 'journey_reminders',
        badgeNumber: 1,
        categoryIdentifier: 'journey_category',
        attachments: imagePath != null
            ? [DarwinNotificationAttachment(imagePath)]
            : null,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    payload: activePath,
  );
}
