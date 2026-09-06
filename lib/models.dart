import 'dart:math';

/// A short random id — no extra package needed for this.
String newId() {
  final rand = Random();
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rnd =
      List.generate(6, (_) => rand.nextInt(36).toRadixString(36)).join();
  return '$ts$rnd';
}

class Task {
  String id;
  String title;
  String? date;
  String? time;
  String description;
  bool reminder;
  int reminderLead;
  bool done;
  String createdAt;

  Task({
    required this.id,
    required this.title,
    this.date,
    this.time,
    this.description = '',
    this.reminder = false,
    this.reminderLead = 10,
    this.done = false,
    required this.createdAt,
  });

  DateTime? get dueDateTime {
    if (date == null || date!.isEmpty) return null;
    final parts = date!.split('-').map(int.parse).toList();
    final t = (time != null && time!.isNotEmpty)
        ? time!.split(':').map(int.parse).toList()
        : [23, 59];

    return DateTime(
      parts[0],
      parts[1],
      parts[2],
      t[0],
      t[1],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'time': time,
        'description': description,
        'reminder': reminder,
        'reminderLead': reminderLead,
        'done': done,
        'createdAt': createdAt,
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        date: j['date'] as String?,
        time: j['time'] as String?,
        description: j['description'] as String? ?? '',
        reminder: j['reminder'] as bool? ?? false,
        reminderLead: j['reminderLead'] as int? ?? 10,
        done: j['done'] as bool? ?? false,
        createdAt:
            j['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      );
}

class ClassItem {
  String id;
  String name;
  String subject;
  String teacher;
  int day;
  String? startTime;
  String? endTime;
  String location;
  String notes;
  bool reminder;
  int reminderLead;

  ClassItem({
    required this.id,
    required this.name,
    this.subject = '',
    this.teacher = '',
    required this.day,
    this.startTime,
    this.endTime,
    this.location = '',
    this.notes = '',
    this.reminder = false,
    this.reminderLead = 10,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'teacher': teacher,
        'day': day,
        'startTime': startTime,
        'endTime': endTime,
        'location': location,
        'notes': notes,
        'reminder': reminder,
        'reminderLead': reminderLead,
      };

  factory ClassItem.fromJson(Map<String, dynamic> j) => ClassItem(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        teacher: j['teacher'] as String? ?? '',
        day: j['day'] as int? ?? 0,
        startTime: j['startTime'] as String?,
        endTime: j['endTime'] as String?,
        location: j['location'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        reminder: j['reminder'] as bool? ?? false,
        reminderLead: j['reminderLead'] as int? ?? 10,
      );
}

/// Records one completed occurrence of a recurring class.
///
/// The ClassItem itself is NEVER marked as permanently completed.
/// Instead, this records that this particular class happened on
/// this particular date.
class ClassCompletion {
  String id;
  String classId;
  String date; // yyyy-MM-dd

  ClassCompletion({
    required this.id,
    required this.classId,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'classId': classId,
        'date': date,
      };

  factory ClassCompletion.fromJson(Map<String, dynamic> j) =>
      ClassCompletion(
        id: j['id'] as String,
        classId: j['classId'] as String? ?? '',
        date: j['date'] as String? ?? '',
      );
}

class Note {
  String id;
  String title;
  String body;
  String updatedAt;

  Note({
    required this.id,
    this.title = '',
    this.body = '',
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updatedAt': updatedAt,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        updatedAt:
            j['updatedAt'] as String? ??
            DateTime.now().toIso8601String(),
      );
}

class StudySessionRecord {
  String id;
  String subject;
  String topic;
  int durationMs;
  String startedAt;
  String endedAt;

  StudySessionRecord({
    required this.id,
    this.subject = '',
    this.topic = '',
    required this.durationMs,
    required this.startedAt,
    required this.endedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'topic': topic,
        'durationMs': durationMs,
        'startedAt': startedAt,
        'endedAt': endedAt,
      };

  factory StudySessionRecord.fromJson(Map<String, dynamic> j) =>
      StudySessionRecord(
        id: j['id'] as String,
        subject: j['subject'] as String? ?? '',
        topic: j['topic'] as String? ?? '',
        durationMs: j['durationMs'] as int? ?? 0,
        startedAt:
            j['startedAt'] as String? ??
            DateTime.now().toIso8601String(),
        endedAt:
            j['endedAt'] as String? ??
            DateTime.now().toIso8601String(),
      );
}

class ActiveSession {
  String subject;
  String topic;
  String status;
  String runningSince;
  int accumulatedMs;
  String startedAt;

  ActiveSession({
    this.subject = '',
    this.topic = '',
    this.status = 'running',
    required this.runningSince,
    this.accumulatedMs = 0,
    required this.startedAt,
  });

  int elapsedMs() {
    var ms = accumulatedMs;

    if (status == 'running') {
      ms += DateTime.now()
          .difference(DateTime.parse(runningSince))
          .inMilliseconds;
    }

    return ms;
  }

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'topic': topic,
        'status': status,
        'runningSince': runningSince,
        'accumulatedMs': accumulatedMs,
        'startedAt': startedAt,
      };

  factory ActiveSession.fromJson(Map<String, dynamic> j) =>
      ActiveSession(
        subject: j['subject'] as String? ?? '',
        topic: j['topic'] as String? ?? '',
        status: j['status'] as String? ?? 'running',
        runningSince:
            j['runningSince'] as String? ??
            DateTime.now().toIso8601String(),
        accumulatedMs: j['accumulatedMs'] as int? ?? 0,
        startedAt:
            j['startedAt'] as String? ??
            DateTime.now().toIso8601String(),
      );
}

class ChatMessage {
  String id;
  String role;
  String content;
  int ts;
  bool error;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.ts,
    this.error = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'ts': ts,
        'error': error,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) =>
      ChatMessage(
        id: j['id'] as String,
        role: j['role'] as String? ?? 'user',
        content: j['content'] as String? ?? '',
        ts: j['ts'] as int? ??
            DateTime.now().millisecondsSinceEpoch,
        error: j['error'] as bool? ?? false,
      );
}

class Conversation {
  String id;
  String title;
  List<ChatMessage> messages;
  String updatedAt;

  Conversation({
    required this.id,
    this.title = '',
    List<ChatMessage>? messages,
    required this.updatedAt,
  }) : messages = messages ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'updatedAt': updatedAt,
      };

  factory Conversation.fromJson(Map<String, dynamic> j) =>
      Conversation(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        messages: ((j['messages'] as List?) ?? [])
            .map(
              (m) => ChatMessage.fromJson(
                Map<String, dynamic>.from(m as Map),
              ),
            )
            .toList(),
        updatedAt:
            j['updatedAt'] as String? ??
            DateTime.now().toIso8601String(),
      );
}

class AppSettings {
  String theme;
  bool sound;
  bool vibration;
  int reminderLead;

  AppSettings({
    this.theme = 'system',
    this.sound = true,
    this.vibration = true,
    this.reminderLead = 10,
  });

  Map<String, dynamic> toJson() => {
        'theme': theme,
        'sound': sound,
        'vibration': vibration,
        'reminderLead': reminderLead,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) =>
      AppSettings(
        theme: j['theme'] as String? ?? 'system',
        sound: j['sound'] as bool? ?? true,
        vibration: j['vibration'] as bool? ?? true,
        reminderLead: j['reminderLead'] as int? ?? 10,
      );
}
