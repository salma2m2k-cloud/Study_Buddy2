import 'package:intl/intl.dart';

const List<String> kDayNamesShort = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const List<String> kDayNamesFull = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

String fmtTime(DateTime d) => DateFormat.jm().format(d);

String fmtDateShort(DateTime d) => DateFormat.MMMd().format(d);

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String durationStr(int ms) {
  final totalSec = (ms / 1000).floor().clamp(0, 1 << 31);
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '${h.toString().padLeft(2, '0')}:$mm:$ss' : '$mm:$ss';
}

String durationHuman(int ms) {
  final totalMin = (ms / 60000).round();
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// Formats a two-digit 'HH:mm' string as a friendly local time, e.g. '2:30 PM'.
String fmtTimeStr(String hhmm) {
  final parts = hhmm.split(':').map(int.parse).toList();
  final now = DateTime.now();
  final d = DateTime(now.year, now.month, now.day, parts[0], parts[1]);
  return fmtTime(d);
}
