import 'package:flutter/foundation.dart';
import 'models.dart';
import 'storage_service.dart';
import 'notification_service.dart';

/// Holds every piece of Study Buddy's data in memory and keeps it in sync
/// with on-device storage. The rule followed throughout: any method that
/// changes data writes it to disk immediately, before notifyListeners —
/// there's no separate "save" step and no explicit save button anywhere
/// in the app.
class AppState extends ChangeNotifier {
  AppState(this._storage, this._notifications);

  final StorageService _storage;
  final NotificationService _notifications;

  List<Task> tasks = [];
  List<ClassItem> classes = [];
  List<Note> notes = [];
  List<StudySessionRecord> sessions = [];
  ActiveSession? activeSession;
  List<Conversation> conversations = [];
  AppSettings settings = AppSettings();

  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    final rawTasks = _storage.readJson(StoreKeys.tasks, <dynamic>[]) as List;
    tasks = rawTasks.map((e) => Task.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    final rawClasses = _storage.readJson(StoreKeys.classes, <dynamic>[]) as List;
    classes = rawClasses.map((e) => ClassItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    final rawNotes = _storage.readJson(StoreKeys.notes, <dynamic>[]) as List;
    notes = rawNotes.map((e) => Note.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    final rawSessions = _storage.readJson(StoreKeys.sessions, <dynamic>[]) as List;
    sessions = rawSessions.map((e) => StudySessionRecord.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    final rawActive = _storage.readJson(StoreKeys.activeSession, null);
    activeSession = rawActive == null ? null : ActiveSession.fromJson(Map<String, dynamic>.from(rawActive as Map));

    final rawConvos = _storage.readJson(StoreKeys.conversations, <dynamic>[]) as List;
    conversations = rawConvos.map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map))).toList();

    final rawSettings = _storage.readJson(StoreKeys.settings, null);
    settings =
        rawSettings == null ? AppSettings() : AppSettings.fromJson(Map<String, dynamic>.from(rawSettings as Map));

    _loaded = true;
    notifyListeners();

    // Re-arm reminders for everything still upcoming. Covers app reinstall
    // or any case where scheduled OS notifications and saved data could
    // have drifted apart.
    await _rescheduleAllReminders();
  }

  Future<void> _persistTasks() => _storage.writeJson(StoreKeys.tasks, tasks.map((t) => t.toJson()).toList());
  Future<void> _persistClasses() => _storage.writeJson(StoreKeys.classes, classes.map((c) => c.toJson()).toList());
  Future<void> _persistNotes() => _storage.writeJson(StoreKeys.notes, notes.map((n) => n.toJson()).toList());
  Future<void> _persistSessions() =>
      _storage.writeJson(StoreKeys.sessions, sessions.map((s) => s.toJson()).toList());
  Future<void> _persistActiveSession() => activeSession == null
      ? _storage.remove(StoreKeys.activeSession)
      : _storage.writeJson(StoreKeys.activeSession, activeSession!.toJson());
  Future<void> _persistConversations() =>
      _storage.writeJson(StoreKeys.conversations, conversations.map((c) => c.toJson()).toList());
  Future<void> _persistSettings() => _storage.writeJson(StoreKeys.settings, settings.toJson());

  // ---------------- Tasks ----------------

  Future<void> addTask(Task task) async {
    tasks.insert(0, task);
    await _persistTasks();
    await _scheduleTaskIfNeeded(task);
    notifyListeners();
  }

  Future<void> updateTask(Task task) async {
    final idx = tasks.indexWhere((t) => t.id == task.id);
    if (idx == -1) return;
    tasks[idx] = task;
    await _persistTasks();
    await _notifications.cancelTaskReminder(task.id);
    await _scheduleTaskIfNeeded(task);
    notifyListeners();
  }

  Future<void> toggleTask(String id) async {
    final idx = tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    tasks[idx].done = !tasks[idx].done;
    await _persistTasks();
    if (tasks[idx].done) {
      await _notifications.cancelTaskReminder(id);
    } else {
      await _scheduleTaskIfNeeded(tasks[idx]);
    }
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    tasks.removeWhere((t) => t.id == id);
    await _persistTasks();
    await _notifications.cancelTaskReminder(id);
    notifyListeners();
  }

  Future<void> _scheduleTaskIfNeeded(Task task) async {
    if (task.done || !task.reminder) return;
    final due = task.dueDateTime;
    if (due == null) return;
    final fireAt = due.subtract(Duration(minutes: task.reminderLead));
    await _notifications.scheduleTaskReminder(
      taskId: task.id,
      title: task.title,
      body: task.reminderLead > 0 ? 'Due in ${task.reminderLead} min' : 'Due now',
      fireAt: fireAt,
    );
  }

  // ---------------- Classes ----------------

  Future<void> addClass(ClassItem c) async {
    classes.add(c);
    await _persistClasses();
    await _scheduleClassIfNeeded(c);
    notifyListeners();
  }

  Future<void> updateClass(ClassItem c) async {
    final idx = classes.indexWhere((x) => x.id == c.id);
    if (idx == -1) return;
    classes[idx] = c;
    await _persistClasses();
    await _notifications.cancelClassReminder(c.id);
    await _scheduleClassIfNeeded(c);
    notifyListeners();
  }

  Future<void> deleteClass(String id) async {
    classes.removeWhere((c) => c.id == id);
    await _persistClasses();
    await _notifications.cancelClassReminder(id);
    notifyListeners();
  }

  Future<void> _scheduleClassIfNeeded(ClassItem c) async {
    if (!c.reminder || c.startTime == null || c.startTime!.isEmpty) return;
    final parts = c.startTime!.split(':').map(int.parse).toList();
    await _notifications.scheduleClassReminder(
      classId: c.id,
      title: c.name,
      body: c.reminderLead > 0 ? 'Starts in ${c.reminderLead} min' : 'Starting now',
      day: c.day,
      hour: parts[0],
      minute: parts[1],
      leadMinutes: c.reminderLead,
    );
  }

  Future<void> _rescheduleAllReminders() async {
    for (final t in tasks) {
      if (!t.done) await _scheduleTaskIfNeeded(t);
    }
    for (final c in classes) {
      await _scheduleClassIfNeeded(c);
    }
  }

  // ---------------- Notes ----------------

  Future<void> upsertNote(Note note) async {
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx == -1) {
      notes.insert(0, note);
    } else {
      notes[idx] = note;
    }
    await _persistNotes();
    notifyListeners();
  }

  Future<void> deleteNote(String id) async {
    notes.removeWhere((n) => n.id == id);
    await _persistNotes();
    notifyListeners();
  }

  // ---------------- Study sessions ----------------

  Future<void> startSession(String subject, String topic) async {
    activeSession = ActiveSession(
      subject: subject,
      topic: topic,
      status: 'running',
      runningSince: DateTime.now().toIso8601String(),
      accumulatedMs: 0,
      startedAt: DateTime.now().toIso8601String(),
    );
    await _persistActiveSession();
    notifyListeners();
  }

  Future<void> pauseSession() async {
    if (activeSession == null) return;
    activeSession!.accumulatedMs = activeSession!.elapsedMs();
    activeSession!.status = 'paused';
    await _persistActiveSession();
    notifyListeners();
  }

  Future<void> resumeSession() async {
    if (activeSession == null) return;
    activeSession!.status = 'running';
    activeSession!.runningSince = DateTime.now().toIso8601String();
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

  // ---------------- Conversations ----------------

  Future<Conversation> createConversation() async {
    final convo = Conversation(id: newId(), title: '', updatedAt: DateTime.now().toIso8601String());
    conversations.insert(0, convo);
    await _persistConversations();
    notifyListeners();
    return convo;
  }

  Future<void> saveConversation(Conversation convo) async {
    final idx = conversations.indexWhere((c) => c.id == convo.id);
    if (idx == -1) {
      conversations.insert(0, convo);
    } else {
      conversations[idx] = convo;
    }
    await _persistConversations();
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    conversations.removeWhere((c) => c.id == id);
    await _persistConversations();
    notifyListeners();
  }

  // ---------------- Settings ----------------

  Future<void> updateSettings(AppSettings Function(AppSettings current) update) async {
    settings = update(settings);
    await _persistSettings();
    notifyListeners();
  }

  // ---------------- Danger zone ----------------

  Future<void> clearAllData() async {
    for (final t in tasks) {
      await _notifications.cancelTaskReminder(t.id);
    }
    for (final c in classes) {
      await _notifications.cancelClassReminder(c.id);
    }
    tasks = [];
    classes = [];
    notes = [];
    sessions = [];
    activeSession = null;
    conversations = [];
    // Settings are kept on purpose — clearing your data shouldn't also
    // reset theme/sound/vibration preferences.
    await _storage.clearAll([
      StoreKeys.tasks,
      StoreKeys.classes,
      StoreKeys.notes,
      StoreKeys.sessions,
      StoreKeys.activeSession,
      StoreKeys.conversations,
    ]);
    notifyListeners();
  }
}
