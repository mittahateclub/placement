import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Fires when a push arrives while the app is in the background or terminated.
///
/// Must be a top-level function (the OS spins up a fresh isolate to run it).
/// Messages that carry a `notification` block are already shown in the tray by
/// the system, so there's nothing to do here for the common case — this exists
/// so data-only messages don't crash and to keep the handler registered.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No Firebase.initializeApp here: a notification-payload message is rendered
  // by the system without our help. Kept intentionally minimal.
}

/// WhatsApp-style server push (FCM): a Cloud Function sends a notification when
/// new content is posted, so students are alerted even with the app closed —
/// no polling, no background service. Complements the on-device scheduled
/// reminders in [NotificationService] (which handle *timed* alerts).
class PushService {
  PushService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static bool _wired = false;
  static String? _token;
  static String? _boundUid;

  /// Register handlers once at startup. Token registration happens later, per
  /// signed-in user, via [bindUser].
  static Future<void> init() async {
    if (_wired) return;
    _wired = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Show heads-up alerts on iOS even while the app is foregrounded.
    await _fcm.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true);

    // Foreground: Android suppresses the system notification, so draw it
    // ourselves through the existing reminder channel.
    FirebaseMessaging.onMessage.listen((m) {
      final n = m.notification;
      if (n == null) return;
      NotificationService.showPush(
          n.title ?? 'UniShip', n.body ?? '', m.data['nav'] as String?);
    });

    // Tapped while backgrounded, or tapped from the tray to cold-start.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTapNav);
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleTapNav(initial);

    _fcm.onTokenRefresh.listen((t) {
      _token = t;
      final uid = _boundUid;
      if (uid != null) _saveToken(uid, t);
    });
  }

  static void _handleTapNav(RemoteMessage m) {
    final nav = m.data['nav'];
    if (nav is String && nav.isNotEmpty) {
      NotificationService.tappedPayload.value = nav;
    }
  }

  /// Associate this device's push token with the signed-in student so the
  /// Cloud Function can target them. Call after the profile is loaded.
  static Future<void> bindUser(String uid) async {
    _boundUid = uid;
    try {
      await _fcm.requestPermission(); // no-op if already granted
      final token = _token ?? await _fcm.getToken();
      if (token == null) return;
      _token = token;
      await _saveToken(uid, token);
    } catch (_) {
      // Missing FCM config (e.g. no google-services.json) must not break login.
    }
  }

  /// Drop this device's token on sign-out so the student stops receiving pushes
  /// here (other signed-in devices keep theirs).
  static Future<void> unbindUser(String uid) async {
    final token = _token;
    _boundUid = null;
    if (token == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayRemove([token]),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> _saveToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmPlatform': defaultTargetPlatform.name,
        'fcmUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
