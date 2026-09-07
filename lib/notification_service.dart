import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  static const _channelId = 'study_buddy_alarm_reminders_v3';
  static const _channelName = 'Study Buddy Reminders';
  static const _channelDescription =
      'Important reminders for tasks and upcoming classes.';

  Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();

      debugPrint(
        'Study Buddy: device timezone = ${timezone.identifier}',
      );

      tz.setLocalLocation(
        tz.getLocation(timezone.identifier),
      );

      debugPrint(
        'Study Buddy: timezone configured = ${tz.local.name}',
      );
    } catch (e) {
      debugPrint(
        'Study Buddy: could not determine timezone: $e',
      );
    }

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initialized = await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
    );

    debugPrint(
      'Study Buddy: notification plugin initialized = $initialized',
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _ready = true;

    debugPrint('Study Buddy: NotificationService READY');
  }

  AndroidFlutterLocalNotificationsPlugin?
      get androidImplementation =>
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin?
      get iosImplementation =>
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

  Future<bool> requestPermissions() async {
    if (!_ready) {
      await init();
    }

    var granted = true;

    final androidImpl = androidImplementation;

    if (androidImpl != null) {
      try {
        final notificationGranted =
            await androidImpl.requestNotificationsPermission();

        debugPrint(
          'Study Buddy: notification permission = '
          '$notificationGranted',
        );

        final exactGranted =
            await androidImpl.requestExactAlarmsPermission();

        debugPrint(
          'Study Buddy: exact alarm permission request result = '
          '$exactGranted',
        );

        granted =
            (notificationGranted ?? true) &&
            (exactGranted ?? true);
      } catch (e, stack) {
        debugPrint(
          'Study Buddy: Android permission error: $e\n$stack',
        );
      }
    }

    final iosImpl = iosImplementation;

    if (iosImpl != null) {
      try {
        final iosGranted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

        granted = granted && (iosGranted ?? true);
      } catch (e) {
        debugPrint(
          'Study Buddy: iOS permission error: $e',
        );
      }
    }

    return granted;
  }

  int _idForTask(String taskId) =>
      ('task:$taskId').hashCode & 0x7fffffff;

  int _idForClass(String classId) =>
      ('class:$classId').hashCode & 0x7fffffff;

  static const _testId = 2147483000;

  NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([
          0,
          800,
          400,
          800,
          400,
          1000,
        ]),
        ticker: 'Study Buddy reminder',
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  // ============================================================
  // IMMEDIATE TEST
  // ============================================================

  Future<void> showTestNotification() async {
    if (!_ready) {
      await init();
    }

    debugPrint(
      'Study Buddy: SHOWING TEST NOTIFICATION',
    );

    await _plugin.show(
      _testId,
      'Study Buddy test 🔔',
      'Notifications are working!',
      _details(),
    );

    debugPrint(
      'Study Buddy: TEST NOTIFICATION SENT',
    );
  }

  // ============================================================
  // TASK REMINDERS
  // ============================================================

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    if (!_ready) {
      await init();
    }

    final now = DateTime.now();

    debugPrint(
      '========================================',
    );
    debugPrint(
      'Study Buddy: TASK REMINDER',
    );
    debugPrint(
      'Task: $title',
    );
    debugPrint(
      'Current local time: $now',
    );
    debugPrint(
      'Requested fire time: $fireAt',
    );
    debugPrint(
      'Timezone: ${tz.local.name}',
    );

    if (!fireAt.isAfter(now)) {
      debugPrint(
        'Study Buddy: NOT SCHEDULED — fire time is already past.',
      );
      debugPrint(
        '========================================',
      );
      return;
    }

    final scheduledTime =
        tz.TZDateTime.from(fireAt, tz.local);

    debugPrint(
      'Timezone scheduled time: $scheduledTime',
    );

    await _plugin.zonedSchedule(
      _idForTask(taskId),
      title,
      body,
      scheduledTime,
      _details(),
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint(
      'Study Buddy: TASK REMINDER SCHEDULED SUCCESSFULLY',
    );

    final pending =
        await _plugin.pendingNotificationRequests();

    debugPrint(
      'Study Buddy: pending notifications = ${pending.length}',
    );

    for (final item in pending) {
      debugPrint(
        'Pending ID=${item.id} title=${item.title}',
      );
    }

    debugPrint(
      '========================================',
    );
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) {
      await init();
    }

    await _plugin.cancel(
      _idForTask(taskId),
    );
  }

  // ============================================================
  // CLASS REMINDERS
  // ============================================================

  Future<void> scheduleClassReminder({
    required String classId,
    required String title,
    required String body,
    required int day,
    required int hour,
    required int minute,
    required int leadMinutes,
  }) async {
    if (!_ready) {
      await init();
    }

    final fireAt = _nextWeeklyOccurrence(
      day,
      hour,
      minute,
      leadMinutes,
    );

    debugPrint(
      '========================================',
    );
    debugPrint(
      'Study Buddy: CLASS REMINDER',
    );
    debugPrint(
      'Class: $title',
    );
    debugPrint(
      'Requested weekday: $day',
    );
    debugPrint(
      'Class time: $hour:$minute',
    );
    debugPrint(
      'Lead minutes: $leadMinutes',
    );
    debugPrint(
      'Timezone: ${tz.local.name}',
    );
    debugPrint(
      'Next reminder: $fireAt',
    );

    await _plugin.zonedSchedule(
      _idForClass(classId),
      title,
      body,
      fireAt,
      _details(),
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint(
      'Study Buddy: CLASS REMINDER SCHEDULED SUCCESSFULLY',
    );

    final pending =
        await _plugin.pendingNotificationRequests();

    debugPrint(
      'Study Buddy: pending notifications = ${pending.length}',
    );

    debugPrint(
      '========================================',
    );
  }

  Future<void> cancelClassReminder(String classId) async {
    if (!_ready) {
      await init();
    }

    await _plugin.cancel(
      _idForClass(classId),
    );
  }

  // ============================================================
  // CANCEL EVERYTHING
  // ============================================================

  Future<void> cancelAll() async {
    if (!_ready) {
      await init();
    }

    await _plugin.cancelAll();
  }

  // ============================================================
  // NEXT WEEKLY OCCURRENCE
  // ============================================================

  tz.TZDateTime _nextWeeklyOccurrence(
    int day,
    int hour,
    int minute,
    int leadMinutes,
  ) {
    final targetWeekday = day == 0 ? 7 : day;

    final now = tz.TZDateTime.now(tz.local);

    var candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(
      Duration(minutes: leadMinutes),
    );

    while (
      candidate.weekday != targetWeekday ||
      !candidate.isAfter(now)
    ) {
      candidate = candidate.add(
        const Duration(days: 1),
      );
    }

    return candidate;
  }
}
