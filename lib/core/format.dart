import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Converts Firestore Timestamp / DateTime / ISO string to DateTime.
DateTime? toDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return null;
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String formatDate(DateTime? d) =>
    d == null ? 'N/A' : DateFormat('MMM d, yyyy').format(d);

String formatDayDate(DateTime? d) =>
    d == null ? 'N/A' : DateFormat('EEE, MMM d').format(d);

String formatTime(DateTime? d) =>
    d == null ? '' : DateFormat('hh:mm a').format(d);

String formatDateTime(DateTime? d) =>
    d == null ? 'N/A' : DateFormat('MMM d, yyyy · hh:mm a').format(d);

/// Compact relative time: "now", "5m", "3h", "2d", else "Mar 4".
String timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inDays < 1) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('MMM d').format(d);
}
