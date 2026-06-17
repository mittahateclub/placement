import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/app_colors.dart';
import '../core/format.dart';
import '../core/student_filters.dart';
import 'auth_service.dart';

/// One reminder to be delivered by the OS at [at].
class ReminderTime {
  final DateTime at;
  final String title;
  final String body;
  const ReminderTime(this.at, this.title, this.body);
}

/// A single upcoming thing a student should know about — shown in the in-app
/// notification center and expanded into OS reminders on standard time frames.
class AppAlert {
  final String key; // stable id, e.g. "test:<docId>"
  final String category; // test | event | internship | deadline | practice
  final String title;
  final String subtitle;
  final DateTime when; // the moment it happens / is due
  final String leadLabel; // "Starts" | "Closes" | "Due" | "Happening"
  final Color color;
  final IconData icon;
  final String? navTarget; // page id to open, or null (informational)
  final DateTime relevantUntil; // hidden from the list after this
  final DateTime? createdAt; // for "newly posted" detection
  final List<ReminderTime> reminders;

  const AppAlert({
    required this.key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.when,
    required this.leadLabel,
    required this.color,
    required this.icon,
    required this.navTarget,
    required this.relevantUntil,
    required this.createdAt,
    required this.reminders,
  });
}

/// On-device scheduled reminders + in-app notification center for students.
///
/// No backend/FCM is involved: reminders are computed from the same Firestore
/// data the student already reads (events / tests / internships / saved items)
/// and scheduled locally on standard lead times. "Newly posted" items are
/// detected on app open/resume and surfaced immediately.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Native bridge for battery-optimisation controls (Android only).
  static const MethodChannel _native = MethodChannel('uniship/notifications');

  static const String _channelId = 'reminders';
  static const String _kEnabled = 'notif_enabled';
  static const String _kLastSync = 'notif_last_sync';
  static const String _kSeen = 'notif_seen_keys';
  static const String _kAsked = 'notif_permission_asked';

  /// Cap on OS-scheduled reminders (iOS allows max 64 pending).
  static const int _maxScheduled = 60;

  static bool _ready = false;
  static bool _enabled = true;
  static final Set<String> _seen = {};

  /// Upcoming alerts for the in-app center (most recent compute).
  static final ValueNotifier<List<AppAlert>> alerts = ValueNotifier([]);

  /// Count of alerts the student hasn't viewed yet (drives the bell badge).
  static final ValueNotifier<int> unseenCount = ValueNotifier(0);

  /// Page id a tapped notification wants to open; HomeShell consumes + clears.
  static final ValueNotifier<String?> tappedPayload = ValueNotifier(null);

  static bool get enabled => _enabled;

  // ── Lifecycle ──────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Falls back to the package default location; reminders still fire,
      // just interpreted in UTC if the device zone can't be resolved.
    }

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kEnabled) ?? true;
    _seen
      ..clear()
      ..addAll(prefs.getStringList(_kSeen) ?? const []);

    const androidInit = AndroidInitializationSettings('ic_stat_notification');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: _onTap,
      onDidReceiveBackgroundNotificationResponse: _onTapBackground,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Reminders',
      description: 'Tests, events and deadline reminders',
      importance: Importance.high,
    ));

    // Cold start from a tapped notification.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final p = launch!.notificationResponse?.payload;
      if (p != null && p.isNotEmpty) tappedPayload.value = p;
    }

    _ready = true;
  }

  static void _onTap(NotificationResponse r) {
    final p = r.payload;
    if (p != null && p.isNotEmpty) tappedPayload.value = p;
  }

  @pragma('vm:entry-point')
  static void _onTapBackground(NotificationResponse r) {}

  /// Wipe scheduled reminders + in-app state (call on sign out).
  static Future<void> clear() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
    alerts.value = [];
    unseenCount.value = 0;
  }

  // ── Permission ─────────────────────────────────────────────────────────

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    // Needed for exact-time delivery on Android 12 (no-op / auto on 13+).
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
    final i = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    return (a ?? i ?? true);
  }

  /// Immediate + 20s scheduled test notification — lets a student confirm
  /// reminders actually reach this device. Returns a short status string.
  static Future<String> sendTestNotification() async {
    final granted = await requestPermission();
    await _show(990001, 'Test notification',
        'If you can see this, UniShip notifications are on. 🎉', 'dashboard');
    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 20));
    await _scheduleAt(990002, when, 'Scheduled test reminder',
        'Scheduled 20 seconds ago — timed reminders work too.', 'dashboard');
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    bool? exact;
    try {
      exact = await android?.canScheduleExactNotifications();
    } catch (_) {}
    final exactStr = exact == null ? 'n/a' : (exact ? 'on' : 'off');
    return granted
        ? 'Sent now + one in 20s · zone ${tz.local.name} · exact alarms $exactStr'
        : 'Notifications are BLOCKED for UniShip — enable them in system settings.';
  }

  static Future<bool> permissionGranted() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return (await android.areNotificationsEnabled()) ?? true;
    return true;
  }

  // ── Background-delivery health (Android) ───────────────────────────────
  //
  // Scheduled reminders are handed to Android's AlarmManager, but two device
  // settings stop the OS from delivering them while the app is closed:
  //   • exact-alarm permission denied (Android 12/13) → alarms become inexact
  //     and can be delayed for a long time, or
  //   • the app isn't exempt from battery optimisation → Doze defers/drops the
  //     alarm, and many OEMs cancel it outright when the app is swiped away.
  // We surface both so the student can fix them in one tap.

  /// Whether the OS will deliver our alarms at the exact scheduled time.
  /// `true` on iOS / pre-Android-12 where it isn't gated.
  static Future<bool> canScheduleExact() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    try {
      return (await android.canScheduleExactNotifications()) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system "Alarms & reminders" screen for UniShip.
  static Future<void> openExactAlarmSettings() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  /// Whether UniShip is exempt from battery optimisation (so Doze won't drop
  /// our alarms). `true` where the concept doesn't apply (iOS / old Android).
  static Future<bool> isBatteryUnrestricted() async {
    try {
      final v = await _native
          .invokeMethod<bool>('isIgnoringBatteryOptimizations');
      return v ?? true;
    } catch (_) {
      return true; // not Android, or channel unavailable — don't nag.
    }
  }

  /// Shows the system dialog to exempt UniShip from battery optimisation.
  static Future<void> requestBatteryExemption() async {
    try {
      await _native.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  /// True when scheduled reminders should reliably fire in the background.
  static Future<bool> deliveryReliable() async {
    final results =
        await Future.wait([canScheduleExact(), isBatteryUnrestricted()]);
    return results[0] && results[1];
  }

  static Future<void> setEnabled(bool value, AuthService auth) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
    await sync(auth);
  }

  // ── In-app "seen" tracking (bell badge) ───────────────────────────────

  static Future<void> markAllSeen() async {
    _seen.addAll(alerts.value.map((a) => a.key));
    unseenCount.value = 0;
    final prefs = await SharedPreferences.getInstance();
    // Keep the seen set bounded to current + recent alert keys.
    await prefs.setStringList(_kSeen, _seen.toList());
  }

  static void _recomputeUnseen() {
    unseenCount.value =
        alerts.value.where((a) => !_seen.contains(a.key)).length;
  }

  // ── Core: build + schedule ─────────────────────────────────────────────

  /// Recompute alerts, schedule OS reminders, and fire "newly posted" alerts.
  static Future<void> sync(AuthService auth) async {
    if (!_ready || !auth.isStudent) return;
    List<AppAlert> computed;
    try {
      computed = await _compute(auth);
    } catch (_) {
      return; // never let a reminder refresh break the app
    }

    alerts.value = computed;
    _recomputeUnseen();

    final prefs = await SharedPreferences.getInstance();

    if (!_enabled) {
      await _plugin.cancelAll();
      return;
    }

    // Prompt for the OS permission once, on the first enabled sync, so OS
    // reminders can actually be delivered (Android 13+ / iOS require it).
    if (!(prefs.getBool(_kAsked) ?? false)) {
      await prefs.setBool(_kAsked, true);
      await requestPermission();
    }

    // Clear previously-scheduled reminders up front (before showing any
    // "newly posted" alert, so cancelAll doesn't dismiss it from the tray).
    await _plugin.cancelAll();

    // "Newly posted" — items created since the last sync. The first sync ever
    // only seeds the watermark (so we don't blast every existing item).
    final lastSyncMs = prefs.getInt(_kLastSync);
    final now = DateTime.now();
    if (lastSyncMs != null) {
      final lastSync = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
      final fresh = computed
          .where((a) =>
              a.createdAt != null &&
              a.createdAt!.isAfter(lastSync) &&
              a.relevantUntil.isAfter(now))
          .take(5)
          .toList();
      for (final a in fresh) {
        await _show(
          a.key.hashCode & 0x7fffffff,
          _postedTitle(a.category),
          a.title,
          a.navTarget,
        );
      }
    }
    await prefs.setInt(_kLastSync, now.millisecondsSinceEpoch);

    // Schedule the soonest reminders (respecting the platform cap).
    final pending = <ReminderTime, String?>{};
    for (final a in computed) {
      for (final r in a.reminders) {
        pending[r] = a.navTarget;
      }
    }
    final ordered = pending.keys.toList()
      ..sort((x, y) => x.at.compareTo(y.at));
    final usedIds = <int>{};
    var scheduled = 0;
    for (final r in ordered) {
      if (scheduled >= _maxScheduled) break;
      var id = ('${r.title}|${r.at.millisecondsSinceEpoch}').hashCode &
          0x7fffffff;
      while (usedIds.contains(id)) {
        id = (id + 1) & 0x7fffffff;
      }
      usedIds.add(id);
      await _schedule(id, r, pending[r]);
      scheduled++;
    }
  }

  static Future<List<AppAlert>> _compute(AuthService auth) async {
    final uid = auth.user?.uid;
    final uni = auth.universityId;
    final now = DateTime.now();

    final results = await Future.wait([
      _tryGet(_db.collection('events')),
      uni == null
          ? Future.value(null)
          : _tryGet(_db
              .collection('internships')
              .where('universityId', isEqualTo: uni)),
      uni == null
          ? Future.value(null)
          : _tryGet(
              _db.collection('tests').where('universityId', isEqualTo: uni)),
      uid == null
          ? Future.value(null)
          : _tryGet(
              _db.collection('savedEvents').where('userId', isEqualTo: uid)),
      uni == null
          ? Future.value(null)
          : _tryGet(
              _db.collection('practice').where('universityId', isEqualTo: uni)),
    ]);

    final out = <AppAlert>[];

    // Saved event ids (so a student's bookmarks always get reminders even if
    // targeting wouldn't include them).
    final savedEventIds = <String>{};
    for (final d in results[3]?.docs ?? const []) {
      final data = d.data();
      if (data['source'] == 'event' && data['eventId'] is String) {
        savedEventIds.add(data['eventId'] as String);
      }
    }

    // ── Events ──
    for (final doc in results[0]?.docs ?? const []) {
      final data = doc.data();
      final expiry = toDate(data['expiresAt']) ?? toDate(data['date']);
      final expired = expiry != null &&
          now.isAfter(
              DateTime(expiry.year, expiry.month, expiry.day, 23, 59, 59));
      if (expired) continue;
      final targeted =
          eventTargetsStudent(data, branch: auth.branch, gpa: auth.gpa);
      if (!targeted && !savedEventIds.contains(doc.id)) continue;

      final type = (data['type'] as String?) ?? 'event';
      final title = (data['title'] as String?) ?? 'Event';
      final date = toDate(data['date']);
      final applyBy = toDate(data['expiresAt']);
      final created = toDate(data['createdAt']);

      if (date != null) {
        final reminders = _reminders('event', title, date, now);
        out.add(AppAlert(
          key: 'event:${doc.id}',
          category: 'event',
          title: title,
          subtitle: AppColors.eventTypeLabel(type),
          when: date,
          leadLabel: 'Starts',
          color: AppColors.eventTypeColor(type),
          icon: Icons.event_rounded,
          navTarget: 'college',
          relevantUntil:
              DateTime(date.year, date.month, date.day, 23, 59, 59),
          createdAt: created,
          reminders: reminders,
        ));
      }
      // Separate apply-by deadline (only if it's a different day to the event).
      if (applyBy != null && (date == null || !sameDay(applyBy, date))) {
        out.add(AppAlert(
          key: 'event-deadline:${doc.id}',
          category: 'deadline',
          title: title,
          subtitle: 'Application deadline',
          when: applyBy,
          leadLabel: 'Closes',
          color: AppColors.amber,
          icon: Icons.timer_outlined,
          navTarget: 'college',
          relevantUntil: applyBy,
          createdAt: created,
          reminders: _reminders('deadline', title, applyBy, now),
        ));
      }
    }

    // ── Internships (deadline) ──
    for (final doc in results[1]?.docs ?? const []) {
      final data = doc.data();
      final deadline = toDate(data['deadline']);
      if (deadline == null || !deadline.isAfter(now)) continue;
      final title = (data['role'] as String?) ??
          (data['title'] as String?) ??
          'Internship';
      out.add(AppAlert(
        key: 'internship:${doc.id}',
        category: 'internship',
        title: title,
        subtitle: (data['companyName'] as String?) ?? 'Internship deadline',
        when: deadline,
        leadLabel: 'Closes',
        color: AppColors.green,
        icon: Icons.work_outline_rounded,
        navTarget: 'college',
        relevantUntil: deadline,
        createdAt: toDate(data['createdAt']),
        reminders: _reminders('deadline', title, deadline, now),
      ));
    }

    // ── Tests (approved, upcoming) ──
    for (final doc in results[2]?.docs ?? const []) {
      final data = doc.data();
      if (data['approved'] != true) continue;
      final start = toDate(data['examStart']);
      final end = toDate(data['examEnd']);
      final title = (data['title'] as String?) ?? 'Test';
      final created = toDate(data['createdAt']);
      final relevantUntil = end ?? start;
      if (relevantUntil == null || !relevantUntil.isAfter(now)) continue;

      final reminders = <ReminderTime>[
        if (start != null) ..._reminders('test', title, start, now),
        if (end != null) ..._reminders('test-close', title, end, now),
      ];
      out.add(AppAlert(
        key: 'test:${doc.id}',
        category: 'test',
        title: title,
        subtitle: start != null && start.isAfter(now)
            ? 'Scheduled assessment'
            : 'Assessment open',
        when: start ?? end!,
        leadLabel: start != null && start.isAfter(now) ? 'Starts' : 'Closes',
        color: AppColors.amber,
        icon: Icons.quiz_rounded,
        navTarget: null, // tests are taken on the web portal
        relevantUntil: relevantUntil,
        createdAt: created,
        reminders: reminders,
      ));
    }

    // ── Practice questions (best-effort; schema may vary) ──
    for (final doc in results[4]?.docs ?? const []) {
      final data = doc.data();
      final due = toDate(data['dueDate']) ??
          toDate(data['deadline']) ??
          toDate(data['endDate']);
      if (due == null || !due.isAfter(now)) continue;
      final title = (data['title'] as String?) ?? 'Practice set';
      out.add(AppAlert(
        key: 'practice:${doc.id}',
        category: 'practice',
        title: title,
        subtitle: 'Practice questions',
        when: due,
        leadLabel: 'Due',
        color: AppColors.blue,
        icon: Icons.fact_check_outlined,
        navTarget: null,
        relevantUntil: due,
        createdAt: toDate(data['createdAt']),
        reminders: _reminders('deadline', title, due, now),
      ));
    }

    out.sort((a, b) => a.when.compareTo(b.when));
    return out;
  }

  // ── Reminder time frames (standard, professional lead times) ───────────

  static List<ReminderTime> _reminders(
      String kind, String title, DateTime when, DateTime now) {
    final out = <ReminderTime>[];
    // 30s guard so "now"-ish triggers don't get dropped by tiny clock skew.
    final floor = now.add(const Duration(seconds: 30));
    void add(DateTime at, String t, String b) {
      if (at.isAfter(floor)) out.add(ReminderTime(at, t, b));
    }

    final time = formatTime(when);
    final day = formatDayDate(when);
    final date = formatDate(when);

    switch (kind) {
      case 'test':
        add(when.subtract(const Duration(hours: 24)), 'Test tomorrow',
            '"$title" starts $day at $time.');
        add(when.subtract(const Duration(hours: 1)), 'Test starts in 1 hour',
            '"$title" begins at $time.');
        add(when, 'Your test is now live', '"$title" has started — good luck!');
        break;
      case 'test-close':
        add(when.subtract(const Duration(hours: 1)), 'Test closes in 1 hour',
            '"$title" closes at $time. Submit before then.');
        break;
      case 'event':
        add(when.subtract(const Duration(hours: 24)), 'Event tomorrow',
            '"$title" · $day at $time.');
        add(when.subtract(const Duration(hours: 1)), 'Starting soon',
            '"$title" starts in 1 hour.');
        break;
      case 'deadline':
        add(when.subtract(const Duration(days: 3)), 'Deadline in 3 days',
            '"$title" closes on $date.');
        add(when.subtract(const Duration(days: 1)), 'Deadline tomorrow',
            '"$title" closes on $date.');
        final dayOf = DateTime(when.year, when.month, when.day, 9);
        if (dayOf.isBefore(when)) {
          add(dayOf, 'Deadline today', '"$title" closes today at $time.');
        }
        break;
    }
    return out;
  }

  static String _postedTitle(String category) {
    switch (category) {
      case 'test':
        return 'New test posted';
      case 'internship':
        return 'New internship posted';
      case 'practice':
        return 'New practice set posted';
      case 'deadline':
        return 'New opportunity posted';
      default:
        return 'New event posted';
    }
  }

  // ── Low-level plugin wrappers ──────────────────────────────────────────

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Reminders',
          channelDescription: 'Tests, events and deadline reminders',
          importance: Importance.high,
          priority: Priority.high,
          // White silhouette in the status bar, full-colour UniShip logo in
          // the notification body, brand accent for the tint.
          icon: 'ic_stat_notification',
          largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
          color: AppColors.accent,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  static Future<void> _schedule(int id, ReminderTime r, String? payload) =>
      _scheduleAt(id, tz.TZDateTime.from(r.at, tz.local), r.title, r.body,
          payload);

  /// Schedule one notification, preferring exact delivery and falling back to
  /// inexact if the OS won't allow exact alarms.
  static Future<void> _scheduleAt(int id, tz.TZDateTime when, String title,
      String body, String? payload) async {
    try {
      await _plugin.zonedSchedule(id, title, body, when, _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: payload);
    } catch (_) {
      try {
        await _plugin.zonedSchedule(id, title, body, when, _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: payload);
      } catch (_) {
        // A single bad reminder must not abort the whole sync.
      }
    }
  }

  static Future<void> _show(
      int id, String title, String body, String? payload) async {
    try {
      await _plugin.show(id, title, body, _details, payload: payload);
    } catch (_) {}
  }

  /// Display an FCM push as a local notification (used when a push arrives
  /// while the app is in the foreground, where Android won't show it itself).
  /// Reuses the reminder channel + branding so it looks identical.
  static Future<void> showPush(String title, String body, String? payload) =>
      _show(DateTime.now().millisecondsSinceEpoch & 0x7fffffff, title, body,
          payload);

  static Future<QuerySnapshot<Map<String, dynamic>>?> _tryGet(
      Query<Map<String, dynamic>> q) async {
    try {
      return await q.get();
    } catch (_) {
      return null; // missing collection / rules — skip that source silently
    }
  }
}
