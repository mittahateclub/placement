import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'auth_service.dart';

/// Support-chat data layer shared by the student widget and the admin inbox.
///
/// Model: one chat per student, `chats/{studentUid}` with a `messages`
/// subcollection. Admin-only notes are messages with `internal: true` —
/// students query with `internal == false` so they never receive them.
class ChatService {
  ChatService._();

  static final _db = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> chatRef(String chatId) =>
      _db.collection('chats').doc(chatId);

  static CollectionReference<Map<String, dynamic>> messagesRef(
          String chatId) =>
      chatRef(chatId).collection('messages');

  /// Creates the student's chat doc on first open, and heals the fields the
  /// admin inbox filters on (universityId, name) for chats created before
  /// the profile was fully loaded.
  static Future<void> ensureChat(AuthService auth) async {
    final uid = auth.user?.uid;
    if (uid == null) return;
    final ref = chatRef(uid);
    final doc = await ref.get();
    if (doc.exists) {
      await ref.set({
        'studentId': uid,
        'studentName': auth.userName ?? auth.user?.email ?? 'Student',
        if (auth.universityId != null) 'universityId': auth.universityId,
      }, SetOptions(merge: true));
      return;
    }
    await ref.set({
      'studentId': uid,
      'studentName': auth.userName ?? auth.user?.email ?? 'Student',
      'universityId': auth.universityId,
      'status': 'open', // open (unassigned) | claimed | closed
      'claimedBy': null,
      'claimedByName': null,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageText': '',
      'studentUnread': 0,
      'adminUnread': 0,
    });
  }

  /// Sends a text and/or file message and updates the chat summary.
  static Future<void> sendMessage({
    required String chatId,
    required AuthService auth,
    String? text,
    Uint8List? fileBytes,
    String? fileName,
    bool internal = false,
  }) async {
    final uid = auth.user?.uid;
    if (uid == null) return;
    final isAdmin = auth.isUniAdmin || auth.isSuperAdmin;

    String? fileUrl;
    if (fileBytes != null && fileName != null) {
      final ref = FirebaseStorage.instance.ref(
          'chat_attachments/$chatId/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      // Storage rules validate the content type, so set it explicitly.
      final ext = fileName.split('.').last.toLowerCase();
      final contentType = switch (ext) {
        'pdf' => 'application/pdf',
        'doc' => 'application/msword',
        'docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'png' => 'image/png',
        _ => 'image/jpeg',
      };
      await ref.putData(fileBytes, SettableMetadata(contentType: contentType));
      fileUrl = await ref.getDownloadURL();
    }

    final batch = _db.batch();
    batch.set(messagesRef(chatId).doc(), {
      'text': text?.trim() ?? '',
      'fileUrl': fileUrl,
      'fileName': fileUrl != null ? fileName : null,
      'senderId': uid,
      'senderName': auth.userName ?? auth.user?.email ?? '',
      'senderRole': isAdmin ? 'admin' : 'student',
      'internal': internal,
      'createdAt': FieldValue.serverTimestamp(),
      // Own messages start seen by their side.
      'seenByStudent': !isAdmin,
      'seenByAdmin': isAdmin,
    });
    if (internal) {
      // Notes don't touch the student-facing summary.
      batch.update(chatRef(chatId), {'lastMessageAt': FieldValue.serverTimestamp()});
    } else {
      batch.update(chatRef(chatId), {
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageText':
            (text?.trim().isNotEmpty ?? false) ? text!.trim() : '📎 $fileName',
        'lastMessageBy': isAdmin ? 'admin' : 'student',
        if (isAdmin)
          'studentUnread': FieldValue.increment(1)
        else
          'adminUnread': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  /// Marks the other side's messages as seen and clears the unread counter.
  static Future<void> markSeen(String chatId, {required bool asAdmin}) async {
    final seenField = asAdmin ? 'seenByAdmin' : 'seenByStudent';
    try {
      final unseen = await messagesRef(chatId)
          .where(seenField, isEqualTo: false)
          .where('internal', isEqualTo: false)
          .limit(200)
          .get();
      final batch = _db.batch();
      for (final doc in unseen.docs) {
        batch.update(doc.reference, {seenField: true});
      }
      batch.update(
          chatRef(chatId), {asAdmin ? 'adminUnread' : 'studentUnread': 0});
      await batch.commit();
    } catch (_) {
      // Receipts are best-effort.
    }
  }

  static Future<void> claim(String chatId, AuthService auth) =>
      chatRef(chatId).update({
        'status': 'claimed',
        'claimedBy': auth.user?.uid,
        'claimedByName': auth.userName ?? auth.user?.email ?? 'Admin',
      });

  static Future<void> close(String chatId) =>
      chatRef(chatId).update({'status': 'closed'});

  static Future<void> reopen(String chatId) => chatRef(chatId).update({
        'status': 'open',
        'claimedBy': null,
        'claimedByName': null,
      });
}
