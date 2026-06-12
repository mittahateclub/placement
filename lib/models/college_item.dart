import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/format.dart';

/// A unified College Space entry — either an `events` doc or an
/// `internships` doc, matching the web app's CollegeEvent shape.
class CollegeItem {
  final String id;
  final String title;
  final DateTime? date;
  final String type;
  final String description;
  final String? location;
  final String source; // 'event' | 'internship'

  // internship-specific
  final String? companyName;
  final String? role;
  final String? stipend;
  final String? duration;

  // event-specific
  final String? link;
  final DateTime? expiresAt;

  /// Raw Firestore data (events) — used for apply + targeting checks.
  final Map<String, dynamic> raw;

  CollegeItem({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    required this.description,
    required this.source,
    this.location,
    this.companyName,
    this.role,
    this.stipend,
    this.duration,
    this.link,
    this.expiresAt,
    this.raw = const {},
  });

  /// End of the day the event stops being relevant (apply-by wins).
  DateTime? get effectiveExpiry {
    final d = expiresAt ?? date;
    return d == null ? null : DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  String get saveKey => '$source-$id';

  factory CollegeItem.fromEvent(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CollegeItem(
      id: doc.id,
      title: (d['title'] as String?) ?? 'Untitled',
      date: toDate(d['date']),
      type: (d['type'] as String?) ?? 'event',
      description: (d['description'] as String?) ?? '',
      location: d['location'] as String?,
      source: 'event',
      companyName: d['company'] as String?,
      link: (d['link'] as String?)?.trim(),
      expiresAt: toDate(d['expiresAt']),
      raw: d,
    );
  }

  factory CollegeItem.fromInternship(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CollegeItem(
      id: doc.id,
      title: (d['role'] as String?) ?? (d['title'] as String?) ?? 'Internship',
      date: toDate(d['deadline']),
      type: 'internship',
      description: (d['description'] as String?) ?? '',
      location: d['location'] as String?,
      source: 'internship',
      companyName: d['companyName'] as String?,
      role: d['role'] as String?,
      stipend: d['stipend'] as String?,
      duration: d['duration'] as String?,
    );
  }

  bool matches(String query) {
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        (companyName?.toLowerCase().contains(q) ?? false) ||
        (location?.toLowerCase().contains(q) ?? false);
  }
}
