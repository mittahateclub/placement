import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../core/student_filters.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/event_post_card.dart';
import '../../widgets/loading_dots.dart';

class StudentDashboard extends StatefulWidget {
  final void Function(String id) onNavigate;
  const StudentDashboard({super.key, required this.onNavigate});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  List<Map<String, dynamic>> _todayEvents = [];
  List<(String, Map<String, dynamic>)> _feed = [];
  Set<String> _trendingIds = {};
  final Map<String, String> _savedIds = {}; // eventId -> savedEvents doc id
  final Set<String> _savingIds = {};
  Set<String> _appliedEventIds = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    try {
      final results = await Future.wait([
        _db.collection('savedEvents').where('userId', isEqualTo: uid).get(),
        _db.collection('events').get(),
        _db
            .collection('eventApplications')
            .where('userId', isEqualTo: uid)
            .get(),
      ]);
      final savedSnap = results[0];
      final eventsSnap = results[1];
      final appliedIds = results[2]
          .docs
          .map((d) => (d.data()['eventId'] as String?) ?? '')
          .toSet();

      final today = DateTime.now();
      _savedIds.clear();
      final todayEvents = <Map<String, dynamic>>[];
      for (final d in savedSnap.docs) {
        final data = d.data();
        if (data['source'] == 'event') {
          _savedIds[data['eventId'] as String? ?? ''] = d.id;
        }
        final date = toDate(data['date']);
        if (date != null && sameDay(date, today)) todayEvents.add(data);
      }

      // Feed: newest first. Expired events (past the end of their apply-by /
      // event day) are hidden from students immediately; admins keep seeing
      // them for a grace period on their side. Targeting (branch / min GPA)
      // is applied here too.
      final now = DateTime.now();
      bool expired(Map<String, dynamic> data) {
        final expiry = toDate(data['expiresAt']) ?? toDate(data['date']);
        if (expiry == null) return false;
        return now.isAfter(
            DateTime(expiry.year, expiry.month, expiry.day, 23, 59, 59));
      }

      final feed = eventsSnap.docs
          .map((d) => (d.id, d.data()))
          .where((e) =>
              !expired(e.$2) &&
              eventTargetsStudent(e.$2, branch: auth.branch, gpa: auth.gpa))
          .toList()
        ..sort((a, b) =>
            (toDate(b.$2['createdAt'] ?? b.$2['date'])
                        ?.millisecondsSinceEpoch ??
                    0)
                .compareTo(
                    toDate(a.$2['createdAt'] ?? a.$2['date'])
                            ?.millisecondsSinceEpoch ??
                        0));

      // Trending = most engagement (comments + RSVPs) among current posts.
      // Counted via aggregate queries so students need no write access.
      final scores = <String, int>{};
      await Future.wait(feed.take(25).map((e) async {
        var score = ((e.$2['attendees'] as List?) ?? []).length;
        try {
          final agg = await _db
              .collection('events')
              .doc(e.$1)
              .collection('comments')
              .count()
              .get();
          score += (agg.count ?? 0) * 2;
        } catch (_) {}
        scores[e.$1] = score;
      }));
      final ranked = scores.entries.where((e) => e.value > 0).toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final trendingIds = ranked.take(2).map((e) => e.key).toSet();

      // Trending posts float to the top of the feed.
      feed.sort((a, b) {
        final at = trendingIds.contains(a.$1) ? 1 : 0;
        final bt = trendingIds.contains(b.$1) ? 1 : 0;
        if (at != bt) return bt - at;
        return 0; // keep recency order otherwise
      });

      if (mounted) {
        setState(() {
          _todayEvents = todayEvents;
          _feed = feed;
          _trendingIds = trendingIds;
          _appliedEventIds = appliedIds;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSave(String eventId, Map<String, dynamic> data) async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    setState(() => _savingIds.add(eventId));
    try {
      final existing = _savedIds[eventId];
      if (existing != null) {
        await _db.collection('savedEvents').doc(existing).delete();
        setState(() => _savedIds.remove(eventId));
      } else {
        final ref = await _db.collection('savedEvents').add({
          'userId': uid,
          'eventId': eventId,
          'source': 'event',
          'title': data['title'],
          'date': data['date'],
          'type': data['type'],
          'description': data['description'],
          'location': data['location'],
          'companyName': null,
          'savedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _savedIds[eventId] = ref.id);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not update bookmark', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingIds.remove(eventId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();

    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;
    final firstName = (auth.userName ?? auth.user?.email ?? 'Student')
        .split(RegExp(r'[ @]'))
        .first;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hey, $firstName 👋',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
            'Here is what is happening on campus',
            style: TextStyle(
                fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),

          // ── Today's events → Calendar ──
          SurfaceCard(
            onTap: () => widget.onNavigate('calendar'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 7),
                    const Text("Today's Events",
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Text(formatDayDate(DateTime.now()),
                        style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurface.withValues(alpha: 0.4))),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.35)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_todayEvents.isEmpty)
                  Text('No events scheduled for today',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurface.withValues(alpha: 0.45)))
                else
                  ..._todayEvents.map((e) {
                    final type = (e['type'] as String?) ?? 'event';
                    final color = AppColors.eventTypeColor(type);
                    final date = toDate(e['date']);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 15, color: color),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(
                                  text: AppColors.eventTypeLabel(type),
                                  style: TextStyle(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5),
                                ),
                                TextSpan(
                                  text: ' — ${e['title'] ?? ''}',
                                  style: const TextStyle(fontSize: 12.5),
                                ),
                              ]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (date != null)
                            Text(formatTime(date),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45))),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Campus feed ──
          if (_feed.isEmpty)
            const EmptyState(
              icon: Icons.dynamic_feed_outlined,
              title: 'No posts yet',
              subtitle:
                  'Events and opportunities from your placement cell appear here',
            )
          else
            ..._feed.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EventPostCard(
                    eventId: e.$1,
                    data: e.$2,
                    trending: _trendingIds.contains(e.$1),
                    saved: _savedIds.containsKey(e.$1),
                    saving: _savingIds.contains(e.$1),
                    onToggleSave: () => _toggleSave(e.$1, e.$2),
                    applied: _appliedEventIds.contains(e.$1),
                    onNavigate: widget.onNavigate,
                  ),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
