import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StoreKeys {
  static const tasks = 'sb_tasks';
  static const classes = 'sb_classes';
  static const classCompletions = 'sb_class_completions';
  static const notes = 'sb_notes';
  static const sessions = 'sb_sessions';
  static const activeSession = 'sb_active_session';
  static const conversations = 'sb_conversations';
  static const settings = 'sb_settings';
  static const alertedReminders = 'sb_alerted_reminders';
}

class StorageService {
  StorageService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<StorageService> open() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  dynamic readJson(String key, dynamic fallback) {
    final raw = _prefs.getString(key);

    if (raw == null) return fallback;

    try {
      return jsonDecode(raw);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> writeJson(String key, dynamic value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  Future<void> clearAll(List<String> keys) async {
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
