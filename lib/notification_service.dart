import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Schedules real, OS-level local notifications for task and class
/// reminders. These are handled by the phone's own alarm/notification
/// system, so they still fire even if Study Buddy isn't open — unlike
/// the original web version, which could only remind you while its tab
/// was open in a browser.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'study_buddy_reminders';
  static const _channelName = 'Task & class reminders';
  static const _channelDescription = 'Reminders for tasks and upcoming classes.';

  Future<void> init() async {
    if (_ready) return;

    tzdata.initializeTimeZones();
    try {
      // Read the device's actual timezone rather than assuming one, so
      // reminders fire at the right local time wherever the student is.
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.name));
    } catch (_) {
      // If this fails, the timezone package's own default is used. Better
      // to proceed than to silently guess a specific region.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _ready = true;
  }

  /// Asks for notification permission (Android 13+, iOS) and, on Android
  /// 12+, the separate "exact alarms" permission reminders need to fire at
  /// a precise time rather than a fuzzy window. Returns true if everything
  /// needed was granted.
  Future<bool> requestPermissions() async {
    var granted = true;

    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final notifGranted = await androidImpl.requestNotificationsPermission();
      final exactGranted = await androidImpl.requestExactAlarmsPermission();
      granted = granted && (notifGranted ?? true) && (exactGranted ?? true);
    }

    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final iosGranted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      granted = granted && (iosGranted ?? true);
    }

    return granted;
  }

  int _idForTask(String taskId) => ('task:$taskId').hashCode & 0x7fffffff;
  int _idForClass(String classId) => ('class:$classId').hashCode & 0x7fffffff;

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      );

  /// One-off reminder for a task at a specific date/time. Does nothing if
  /// that moment has already passed.
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskReminder(String taskId) => _plugin.cancel(_idForTask(taskId));

  /// Recurring weekly reminder for a class — fires every week on the same
  /// day and time, so it keeps working without having to be recreated
  /// each week.
  Future<void> scheduleClassReminder({
    required String classId,
    required String title,
    required String body,
    required int day, // 0 = Sunday .. 6 = Saturday
    required int hour,
    required int minute,
    required int leadMinutes,
  }) async {
    if (!_ready) return;
    final fireAt = _nextWeeklyOccurrence(day, hour, minute, leadMinutes);
    await _plugin.zonedSchedule(
      _idForClass(classId),
      title,
      body,
      fireAt,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelClassReminder(String classId) => _plugin.cancel(_idForClass(classId));

  tz.TZDateTime _nextWeeklyOccurrence(int day, int hour, int minute, int leadMinutes) {
    // DateTime.weekday is 1=Monday..7=Sunday; our `day` field is 0=Sunday..6=Saturday.
    final targetWeekday = day == 0 ? 7 : day;
    final now = tz.TZDateTime.now(tz.local);
    var candidate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
        .subtract(Duration(minutes: leadMinutes));
    while (candidate.weekday != targetWeekday || candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
}
