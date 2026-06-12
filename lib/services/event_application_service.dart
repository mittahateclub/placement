import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// In-app applications for events posted without an external link.
/// One doc per (event, student) in `eventApplications`; the admin's
/// applicants page reads them per event.
class EventApplicationService {
  EventApplicationService._();

  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get ref =>
      _db.collection('eventApplications');

  /// Event ids this student has applied to.
  static Future<Set<String>> appliedEventIds(String uid) async {
    final snap = await ref.where('userId', isEqualTo: uid).get();
    return snap.docs
        .map((d) => (d.data()['eventId'] as String?) ?? '')
        .toSet();
  }

  static Future<void> apply({
    required String eventId,
    required Map<String, dynamic> eventData,
    required AuthService auth,
  }) async {
    final uid = auth.user?.uid;
    if (uid == null) return;
    await ref.add({
      'eventId': eventId,
      'eventTitle': eventData['title'],
      'universityId': eventData['universityId'],
      'userId': uid,
      'userName': auth.userName ?? auth.user?.email ?? 'Student',
      'userEmail': auth.user?.email,
      'branch': auth.branch,
      'gpa': auth.gpa,
      'appliedAt': FieldValue.serverTimestamp(),
    });
  }
}
