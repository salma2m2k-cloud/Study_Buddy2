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

  static const _channelId = 'study_buddy_alarm_reminders_v2';
  static const _channelName = 'Study Buddy Reminders';
  static const _channelDescription =
      'Important reminders for tasks and upcoming classes.';

  Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();

    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {}

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
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
      final notifGranted =
          await androidImpl.requestNotificationsPermission();

      final exactGranted =
          await androidImpl.requestExactAlarmsPermission();

      granted = granted &&
          (notifGranted ?? true) &&
          (exactGranted ?? true);
    }

    final iosImpl = iosImplementation;

    if (iosImpl != null) {
      final iosGranted = await iosImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      granted = granted && (iosGranted ?? true);
    }

    return granted;
  }

  int _idForTask(String taskId) =>
      ('task:$taskId').hashCode & 0x7fffffff;

  int _idForClass(String classId) =>
      ('class:$classId').hashCode & 0x7fffffff;

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

  if (!fireAt.isAfter(now)) {
    debugPrint(
      'Study Buddy: reminder NOT scheduled because fireAt '
      '($fireAt) is already in the past. Now: $now',
    );
    return;
  }

  final scheduledTime =
      tz.TZDateTime.from(fireAt, tz.local);

  debugPrint(
    'Study Buddy: scheduling task reminder\n'
    'Task: $title\n'
    'Local fireAt: $fireAt\n'
    'Timezone fireAt: $scheduledTime\n'
    'Now: ${tz.TZDateTime.now(tz.local)}',
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
    'Study Buddy: task reminder scheduled successfully.',
  );
}

  Future<void> cancelTaskReminder(String taskId) async {
    try {
      await _plugin.cancel(_idForTask(taskId));
    } catch (_) {}
  }

  Future<void> scheduleClassReminder({
    required String classId,
    required String title,
    required String body,
    required int day,
    required int hour,
    required int minute,
    required int leadMinutes,
  }) async {
    if (!_ready) return;

    final fireAt = _nextWeeklyOccurrence(
      day,
      hour,
      minute,
      leadMinutes,
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
  }

  Future<void> cancelClassReminder(String classId) async {
    try {
      await _plugin.cancel(_idForClass(classId));
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

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
        candidate.isBefore(now)) {
      candidate = candidate.add(
        const Duration(days: 1),
      );
    }

    return candidate;
  }
}
