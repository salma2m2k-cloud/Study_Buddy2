import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Study Buddy notification service.
///
/// Handles real OS-level reminders for tasks and recurring classes.
/// Notifications are designed to be highly visible with sound + vibration.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  // New channel ID so Android creates a fresh channel with the new
  // sound/vibration settings instead of reusing the old channel.
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
    } catch (_) {
      // Keep the timezone package's default if the device timezone
      // cannot be detected.
    }

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

    // Android notification channel.
    //
    // MAX importance + sound + vibration makes reminders much harder
    // to miss than a normal silent notification.
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

  /// Requests the permissions needed for visible/sounding notifications
  /// and exact scheduled alarms.
  Future<bool> requestPermissions() async {
    var granted = true;

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final notifGranted =
          await androidImpl.requestNotificationsPermission();

      final exactGranted =
          await androidImpl.requestExactAlarmsPermission();

      granted = granted &&
          (notifGranted ?? true) &&
          (exactGranted ?? true);
    }

    final iosImpl =
        _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

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

  /// Notification appearance/behavior.
  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,

        // Make it a very important notification.
        importance: Importance.max,
        priority: Priority.max,

        // Sound.
        playSound: true,

        // Strong vibration pattern:
        // vibrate → pause → vibrate → pause → vibrate.
        enableVibration: true,
        vibrationPattern: Int64List.fromList([
          0,
          800,
          400,
          800,
          400,
          1000,
        ]),

        // Keep it visible as a heads-up notification.
        ticker: 'Study Buddy reminder',

        category: AndroidNotificationCategory.reminder,

        // Show it on the lock screen.
        visibility: NotificationVisibility.public,
      ),

      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  /// Schedule a one-time task reminder.
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime fireAt,
  }) async {
    if (!_ready) return;

    if (fireAt.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      _idForTask(taskId),
      title,
      body,
      tz.TZDateTime.from(fireAt, tz.local),
      _details(),
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel a task reminder.
  Future<void> cancelTaskReminder(String taskId) async {
    try {
      await _plugin.cancel(_idForTask(taskId));
    } catch (_) {}
  }

  /// Schedule a recurring weekly class reminder.
  ///
  /// The class remains scheduled every week until the reminder is
  /// disabled or the class is deleted.
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

  /// Cancel a recurring class reminder.
  Future<void> cancelClassReminder(String classId) async {
    try {
      await _plugin.cancel(_idForClass(classId));
    } catch (_) {}
  }

  /// Cancel every Study Buddy notification.
  ///
  /// Used by "Clear all data" so old reminders cannot remain scheduled.
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
    // App format:
    // 0 = Sunday
    // 1 = Monday
    // ...
    // 6 = Saturday
    //
    // DateTime.weekday:
    // 1 = Monday
    // ...
    // 7 = Sunday
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
