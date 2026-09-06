import 'package:flutter/foundation.dart';

import 'models.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// Holds every piece of Study Buddy's data in memory and keeps it in sync
/// with on-device storage.
///
/// Data is always persisted immediately. Notification work is treated as
/// secondary: a notification problem must never prevent the app from
/// adding, editing, or deleting data.
class AppState extends ChangeNotifier {
  AppState(this._storage, this._notifications);

  final StorageService _storage;
  final NotificationService _notifications;

  List<Task> tasks = [];
  List<ClassItem> classes = [];
  List<ClassCompletion> classCompletions = [];
  List<Note> notes = [];
  List<StudySessionRecord> sessions = [];
  ActiveSession? activeSession;
  List<Conversation> conversations = [];
  AppSettings settings = AppSettings();

  bool _loaded = false;

  bool get loaded => _loaded;

  // ---------------- Loading ----------------

  Future<void> load() async {
    final rawTasks =
        _storage.readJson(StoreKeys.tasks, <dynamic>[]) as List;

    tasks = rawTasks
        .map(
          (e) => Task.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final rawClasses =
        _storage.readJson(StoreKeys.classes, <dynamic>[]) as List;

    classes = rawClasses
        .map(
          (e) => ClassItem.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    final rawCompletions =
    _storage.readJson(
      StoreKeys.classCompletions,
      <dynamic>[],
    ) as List;

classCompletions = rawCompletions
    .map(
      (e) => ClassCompletion.fromJson(
        Map<String, dynamic>.from(e as Map),
      ),
    )
    .toList();

    final rawNotes =
        _storage.readJson(StoreKeys.notes, <dynamic>[]) as List;

    notes = rawNotes
        .map(
          (e) => Note.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final rawSessions =
        _storage.readJson(StoreKeys.sessions, <dynamic>[]) as List;

    sessions = rawSessions
        .map(
          (e) => StudySessionRecord.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final rawActive =
        _storage.readJson(StoreKeys.activeSession, null);

    activeSession = rawActive == null
        ? null
        : ActiveSession.fromJson(
            Map<String, dynamic>.from(rawActive as Map),
          );

    final rawConversations =
        _storage.readJson(StoreKeys.conversations, <dynamic>[]) as List;

    conversations = rawConversations
        .map(
          (e) => Conversation.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();

    final rawSettings =
        _storage.readJson(StoreKeys.settings, null);

    settings = rawSettings == null
        ? AppSettings()
        : AppSettings.fromJson(
            Map<String, dynamic>.from(rawSettings as Map),
          );

    // The app is ready NOW.
    _loaded = true;
    notifyListeners();

    // Restore reminders separately.
    // Never wait for notification scheduling during startup.
    _rescheduleAllRemindersSafely();
  }

  // ---------------- Persistence ----------------

  Future<void> _persistTasks() {
    return _storage.writeJson(
      StoreKeys.tasks,
      tasks.map((t) => t.toJson()).toList(),
    );
  }

  Future<void> _persistClasses() {
    return _storage.writeJson(
      StoreKeys.classes,
      classes.map((c) => c.toJson()).toList(),
    );
  }
  Future<void> _persistClassCompletions() {
  return _storage.writeJson(
    StoreKeys.classCompletions,
    classCompletions.map((c) => c.toJson()).toList(),
  );
}

  Future<void> _persistNotes() {
    return _storage.writeJson(
      StoreKeys.notes,
      notes.map((n) => n.toJson()).toList(),
    );
  }

  Future<void> _persistSessions() {
    return _storage.writeJson(
      StoreKeys.sessions,
      sessions.map((s) => s.toJson()).toList(),
    );
  }

  Future<void> _persistActiveSession() {
    if (activeSession == null) {
      return _storage.remove(StoreKeys.activeSession);
    }

    return _storage.writeJson(
      StoreKeys.activeSession,
      activeSession!.toJson(),
    );
  }

  Future<void> _persistConversations() {
    return _storage.writeJson(
      StoreKeys.conversations,
      conversations.map((c) => c.toJson()).toList(),
    );
  }

  Future<void> _persistSettings() {
    return _storage.writeJson(
      StoreKeys.settings,
      settings.toJson(),
    );
  }

  // ============================================================
  // TASKS
  // ============================================================

  Future<void> addTask(Task task) async {
    tasks.insert(0, task);

    // Save first.
    await _persistTasks();

    // Tell the UI immediately.
    notifyListeners();

    // Notification is secondary.
    _scheduleTaskSafely(task);
  }

  Future<void> updateTask(Task task) async {
    final index = tasks.indexWhere((t) => t.id == task.id);

    if (index == -1) return;

    tasks[index] = task;

    // Save first.
    await _persistTasks();

    // Update UI immediately.
    notifyListeners();

    // Notification work happens separately.
    _updateTaskReminderSafely(task);
  }

  Future<void> toggleTask(String id) async {
    final index = tasks.indexWhere((t) => t.id == id);

    if (index == -1) return;

    tasks[index].done = !tasks[index].done;

    // Save first.
    await _persistTasks();

    // Update UI immediately.
    notifyListeners();

    // Notification work happens separately.
    _toggleTaskReminderSafely(tasks[index]);
  }

  Future<void> deleteTask(String id) async {
    tasks.removeWhere((t) => t.id == id);

    // Save deletion first.
    await _persistTasks();

    // Remove from UI immediately.
    notifyListeners();

    // Cancel reminder separately.
    _cancelTaskReminderSafely(id);
  }

  Future<void> _scheduleTaskSafely(Task task) async {
    try {
      await _scheduleTaskIfNeeded(task);
    } catch (_) {
      // Notification failure must never affect task data.
    }
  }

  Future<void> _updateTaskReminderSafely(Task task) async {
    try {
      await _notifications.cancelTaskReminder(task.id);
      await _scheduleTaskIfNeeded(task);
    } catch (_) {
      // Ignore notification errors.
    }
  }

  Future<void> _toggleTaskReminderSafely(Task task) async {
    try {
      if (task.done) {
        await _notifications.cancelTaskReminder(task.id);
      } else {
        await _scheduleTaskIfNeeded(task);
      }
    } catch (_) {
      // Ignore notification errors.
    }
  }

  Future<void> _cancelTaskReminderSafely(String id) async {
    try {
      await _notifications.cancelTaskReminder(id);
    } catch (_) {
      // Ignore notification errors.
    }
  }

  Future<void> _scheduleTaskIfNeeded(Task task) async {
    if (task.done || !task.reminder) return;

    final due = task.dueDateTime;

    if (due == null) return;

    final fireAt =
        due.subtract(Duration(minutes: task.reminderLead));

    await _notifications.scheduleTaskReminder(
      taskId: task.id,
      title: task.title,
      body: task.reminderLead > 0
          ? 'Due in ${task.reminderLead} min'
          : 'Due now',
      fireAt: fireAt,
    );
  }

  // ============================================================
  // CLASSES
  // ============================================================

  Future<void> addClass(ClassItem classItem) async {
    classes.add(classItem);

    // Save first.
    await _persistClasses();

    // Update UI immediately.
    notifyListeners();

    // Notification work happens separately.
    _scheduleClassSafely(classItem);
  }

  Future<void> updateClass(ClassItem classItem) async {
    final index =
        classes.indexWhere((c) => c.id == classItem.id);

    if (index == -1) return;

    classes[index] = classItem;

    // Save first.
    await _persistClasses();

    // Update UI immediately.
    notifyListeners();

    // Notification work happens separately.
    _updateClassReminderSafely(classItem);
  }

  Future<void> deleteClass(String id) async {
  classes.removeWhere((c) => c.id == id);

  classCompletions.removeWhere(
    (completion) => completion.classId == id,
  );

  await _persistClasses();
  await _persistClassCompletions();

  notifyListeners();

  _cancelClassReminderSafely(id);
}

  Future<void> _scheduleClassSafely(
    ClassItem classItem,
  ) async {
    try {
      await _scheduleClassIfNeeded(classItem);
    } catch (_) {
      // Notification failure must never affect class data.
    }
  }

  Future<void> _updateClassReminderSafely(
    ClassItem classItem,
  ) async {
    try {
      await _notifications.cancelClassReminder(
        classItem.id,
      );

      await _scheduleClassIfNeeded(classItem);
    } catch (_) {
      // Ignore notification errors.
    }
  }

  Future<void> _cancelClassReminderSafely(String id) async {
    try {
      await _notifications.cancelClassReminder(id);
    } catch (_) {
      // Ignore notification errors.
    }
  }

  Future<void> _scheduleClassIfNeeded(
    ClassItem classItem,
  ) async {
    if (!classItem.reminder ||
        classItem.startTime == null ||
        classItem.startTime!.isEmpty) {
      return;
    }

    final parts =
        classItem.startTime!.split(':').map(int.parse).toList();

    await _notifications.scheduleClassReminder(
      classId: classItem.id,
      title: classItem.name,
      body: classItem.reminderLead > 0
          ? 'Starts in ${classItem.reminderLead} min'
          : 'Starting now',
      day: classItem.day,
      hour: parts[0],
      minute: parts[1],
      leadMinutes: classItem.reminderLead,
    );
  }
  // ============================================================
// CLASS COMPLETION + WEEKLY PROGRESS
// ============================================================

String _dateKey(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

/// Returns the Monday of the current week.
DateTime get startOfCurrentWeek {
  final now = DateTime.now();

  return DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(
    Duration(days: now.weekday - 1),
  );
}

/// Returns the Sunday of the current week.
DateTime get endOfCurrentWeek {
  return startOfCurrentWeek.add(
    const Duration(days: 6),
  );
}

/// Returns the date on which a recurring class occurs
/// during the current week.
DateTime occurrenceDateFor(
  ClassItem classItem,
) {
  final monday = startOfCurrentWeek;

  // App day:
  // 0 = Sunday
  // 1 = Monday
  // ...
  // 6 = Saturday
  //
  // Convert it to Monday-based offset.
  final offset = classItem.day == 0
      ? 6
      : classItem.day - 1;

  return DateTime(
    monday.year,
    monday.month,
    monday.day + offset,
  );
}

/// Whether this week's occurrence of a class is completed.
bool isClassCompletedThisWeek(
  ClassItem classItem,
) {
  final date = _dateKey(
    occurrenceDateFor(classItem),
  );

  return classCompletions.any(
    (completion) =>
        completion.classId == classItem.id &&
        completion.date == date,
  );
}

/// Mark this week's occurrence as completed.
Future<void> finishClass(ClassItem classItem) async {
  final date = _dateKey(
    occurrenceDateFor(classItem),
  );

  final alreadyCompleted = classCompletions.any(
    (completion) =>
        completion.classId == classItem.id &&
        completion.date == date,
  );

  if (alreadyCompleted) return;

  classCompletions.add(
    ClassCompletion(
      id: newId(),
      classId: classItem.id,
      date: date,
    ),
  );

  await _persistClassCompletions();
  notifyListeners();
}

/// Undo completion if the student accidentally tapped it.
Future<void> unfinishClass(ClassItem classItem) async {
  final date = _dateKey(
    occurrenceDateFor(classItem),
  );

  classCompletions.removeWhere(
    (completion) =>
        completion.classId == classItem.id &&
        completion.date == date,
  );

  await _persistClassCompletions();
  notifyListeners();
}

/// Number of recurring class occurrences this week.
int get weeklyClassCount {
  return classes.length;
}

/// Number completed this week.
int get weeklyCompletedClassCount {
  return classes.where(
    isClassCompletedThisWeek,
  ).length;
}

/// Number still remaining this week.
int get weeklyRemainingClassCount {
  return weeklyClassCount -
      weeklyCompletedClassCount;
}

/// Completion percentage from 0.0 to 1.0.
double get weeklyClassProgress {
  if (weeklyClassCount == 0) return 0;

  return weeklyCompletedClassCount /
      weeklyClassCount;
}
  

  // ============================================================
  // RESTORE REMINDERS
  // ============================================================

  Future<void> _rescheduleAllRemindersSafely() async {
    for (final task in tasks) {
      if (task.done) continue;

      try {
        await _scheduleTaskIfNeeded(task);
      } catch (_) {
        // One broken task reminder must not affect anything else.
      }
    }

    for (final classItem in classes) {
      try {
        await _scheduleClassIfNeeded(classItem);
      } catch (_) {
        // One broken class reminder must not affect anything else.
      }
    }
  }

  // ============================================================
  // NOTES
  // ============================================================

  Future<void> upsertNote(Note note) async {
    final index = notes.indexWhere((n) => n.id == note.id);

    if (index == -1) {
      notes.insert(0, note);
    } else {
      notes[index] = note;
    }

    await _persistNotes();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    notes.removeWhere((n) => n.id == id);

    await _persistNotes();
    notifyListeners();
  }

  // ============================================================
  // STUDY SESSIONS
  // ============================================================

  Future<void> startSession(
    String subject,
    String topic,
  ) async {
    final now = DateTime.now().toIso8601String();

    activeSession = ActiveSession(
      subject: subject,
      topic: topic,
      status: 'running',
      runningSince: now,
      accumulatedMs: 0,
      startedAt: now,
    );

    await _persistActiveSession();
    notifyListeners();
  }

  Future<void> pauseSession() async {
    if (activeSession == null) return;

    activeSession!.accumulatedMs =
        activeSession!.elapsedMs();

    activeSession!.status = 'paused';

    await _persistActiveSession();
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (activeSession == null) return;

    activeSession!.status = 'running';
    activeSession!.runningSince =
        DateTime.now().toIso8601String();

    await _persistActiveSession();
    notifyListeners();
  }

  Future<void> stopSession() async {
    if (activeSession == null) return;

    final totalMs = activeSession!.elapsedMs();

    if (totalMs > 3000) {
      sessions.insert(
        0,
        StudySessionRecord(
          id: newId(),
          subject: activeSession!.subject,
          topic: activeSession!.topic,
          durationMs: totalMs,
          startedAt: activeSession!.startedAt,
          endedAt: DateTime.now().toIso8601String(),
        ),
      );

      await _persistSessions();
    }

    activeSession = null;

    await _persistActiveSession();
    notifyListeners();
  }

  // ============================================================
  // CONVERSATIONS
  // ============================================================

  Future<Conversation> createConversation() async {
    final conversation = Conversation(
      id: newId(),
      title: '',
      updatedAt: DateTime.now().toIso8601String(),
    );

    conversations.insert(0, conversation);

    await _persistConversations();
    notifyListeners();

    return conversation;
  }

  Future<void> saveConversation(
    Conversation conversation,
  ) async {
    final index =
        conversations.indexWhere(
      (c) => c.id == conversation.id,
    );

    if (index == -1) {
      conversations.insert(0, conversation);
    } else {
      conversations[index] = conversation;
    }

    await _persistConversations();
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    conversations.removeWhere((c) => c.id == id);

    await _persistConversations();
    notifyListeners();
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Future<void> updateSettings(
    AppSettings Function(AppSettings current) update,
  ) async {
    settings = update(settings);

    await _persistSettings();
    notifyListeners();
  }

  // ============================================================
  // CLEAR ALL DATA
  // ============================================================

  Future<void> clearAllData() async {
  tasks = [];
  classes = [];
  classCompletions = [];
  notes = [];
  sessions = [];
  activeSession = null;
  conversations = [];

  await _storage.clearAll([
    StoreKeys.tasks,
    StoreKeys.classes,
    StoreKeys.classCompletions,
    StoreKeys.notes,
    StoreKeys.sessions,
    StoreKeys.activeSession,
    StoreKeys.conversations,
  ]);

  notifyListeners();

  _cancelAllRemindersSafely();
}

Future<void> _cancelAllRemindersSafely() async {
  try {
    await _notifications.cancelAll();
  } catch (_) {}
}
}
