import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Every key Study Buddy persists on the device. Kept in one place so it's
/// obvious exactly what data the app saves.
class StoreKeys {
  static const tasks = 'sb_tasks';
  static const classes = 'sb_classes';
  static const notes = 'sb_notes';
  static const sessions = 'sb_sessions';
  static const activeSession = 'sb_active_session';
  static const conversations = 'sb_conversations';
  static const settings = 'sb_settings';
  static const alertedReminders = 'sb_alerted_reminders';
}

/// Thin wrapper around shared_preferences. Every read/write goes through
/// here so the rest of the app never touches the storage API directly.
///
/// shared_preferences stores data on the device itself (SharedPreferences
/// on Android, NSUserDefaults on iOS) — nothing goes to a server. That's
/// deliberate: this app has no account system and no cloud database, so
/// there's nothing to keep in sync and nothing that requires a network
/// connection to work.
class StorageService {
  StorageService._(this._prefs);
  final SharedPreferences _prefs;

  static Future<StorageService> open() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  /// Reads and JSON-decodes a raw value. Returns [fallback] if nothing is
  /// stored yet, or if the stored value can't be parsed (so a corrupted
  /// entry can never crash the app on launch).
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
