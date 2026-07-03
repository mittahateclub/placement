import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../core/student_filters.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common.dart';
import '../../widgets/event_post_card.dart';
import '../../widgets/loading_dots.dart';
import 'internship_detail_screen.dart';

/// One item in the unified home feed — an event (any type) or an internship.
class _FeedItem {
  final String source; // 'event' | 'internship'
  final String id;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
  final DateTime? expiry;
  int engagement = 0; // comments + RSVPs (events only)
  int score = 0; // engagement + recency + expiry urgency

  _FeedItem(this.source, this.id, this.data, {this.createdAt, this.expiry});

  String get key => '$source-$id';
}

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
  List<_FeedItem> _feed = [];
  Set<String> _trendingKeys = {}; // 'source-id' of trending items
  final Map<String, String> _savedIds = {}; // 'source-id' -> savedEvents doc id
  final Set<String> _savingIds = {}; // 'source-id' currently toggling
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
      final uni = auth.universityId;
      final results = await Future.wait([
        _db.collection('savedEvents').where('userId', isEqualTo: uid).get(),
        _db.collection('events').get(),
        _db
            .collection('eventApplications')
            .where('userId', isEqualTo: uid)
            .get(),
        uni == null
            ? Future.value(null)
            : _db
                .collection('internships')
                .where('universityId', isEqualTo: uni)
                .get(),
      ]);
      final savedSnap = results[0]!;
      final eventsSnap = results[1]!;
      final appliedIds = results[2]!
          .docs
          .map((d) => (d.data()['eventId'] as String?) ?? '')
          .toSet();
      final internSnap = results[3];

      final now = DateTime.now();
      _savedIds.clear();
      final todayEvents = <Map<String, dynamic>>[];
      for (final d in savedSnap.docs) {
        final data = d.data();
        final src = (data['source'] as String?) ?? 'event';
        _savedIds['$src-${data['eventId']}'] = d.id;
        final date = toDate(data['date']);
        if (date != null && sameDay(date, now)) todayEvents.add(data);
      }

      // Hide anything past the end of its apply-by / deadline / event day.
      bool expired(DateTime? expiry) {
        if (expiry == null) return false;
        return now.isAfter(
            DateTime(expiry.year, expiry.month, expiry.day, 23, 59, 59));
      }

      // Unified feed: all targeted events (any type) + the university's
      // internships. Same source of truth as College Space.
      final items = <_FeedItem>[];
      for (final d in eventsSnap.docs) {
        final data = d.data();
        final expiry = toDate(data['expiresAt']) ?? toDate(data['date']);
        if (expired(expiry)) continue;
        if (!eventTargetsStudent(data, branch: auth.branch, gpa: auth.gpa)) {
          continue;
        }
        items.add(_FeedItem('event', d.id, data,
            createdAt: toDate(data['createdAt'] ?? data['date']),
            expiry: expiry));
      }
      for (final d in internSnap?.docs ?? const []) {
        final data = d.data();
        final deadline = toDate(data['deadline']);
        if (expired(deadline)) continue;
        items.add(_FeedItem('internship', d.id, data,
            createdAt: toDate(data['createdAt'] ?? data['deadline']),
            expiry: deadline));
      }

      // Engagement (events only — internship reactions aren't student-readable).
      // Aggregate counts so students need no write access.
      items.sort((a, b) => (b.createdAt?.millisecondsSinceEpoch ?? 0)
          .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0));
      await Future.wait(
          items.take(25).where((i) => i.source == 'event').map((i) async {
        var eng = ((i.data['attendees'] as List?) ?? []).length;
        try {
          final agg = await _db
              .collection('events')
              .doc(i.id)
              .collection('comments')
              .count()
              .get();
          eng += (agg.count ?? 0) * 2;
        } catch (_) {}
        i.engagement = eng;
      }));

      // Trending score = engagement + freshness + deadline urgency.
      for (final i in items) {
        i.score = i.engagement +
            _recencyPoints(i.createdAt, now) +
            _urgencyPoints(i.expiry, now);
      }
      final trendingKeys = (items.where((i) => i.score > 2).toList()
            ..sort((a, b) => b.score.compareTo(a.score)))
          .take(3)
          .map((i) => i.key)
          .toSet();

      // Trending floats to the top (by score); everything else by recency.
      items.sort((a, b) {
        final at = trendingKeys.contains(a.key) ? 1 : 0;
        final bt = trendingKeys.contains(b.key) ? 1 : 0;
        if (at != bt) return bt - at;
        if (at == 1) return b.score.compareTo(a.score);
        return (b.createdAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0);
      });

      if (mounted) {
        setState(() {
          _todayEvents = todayEvents;
          _feed = items;
          _trendingKeys = trendingKeys;
          _appliedEventIds = appliedIds;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Newer posts rank higher.
  int _recencyPoints(DateTime? createdAt, DateTime now) {
    if (createdAt == null) return 0;
    final h = now.difference(createdAt).inHours;
    if (h < 24) return 4;
    if (h < 72) return 2;
    if (h < 168) return 1;
    return 0;
  }

  /// Items closing soon surface as trending.
  int _urgencyPoints(DateTime? expiry, DateTime now) {
    if (expiry == null) return 0;
    final h = expiry.difference(now).inHours;
    if (h < 0) return 0;
    if (h < 24) return 5;
    if (h < 48) return 3;
    if (h < 168) return 1;
    return 0;
  }

  Future<void> _toggleSave(_FeedItem item) async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    final key = item.key;
    setState(() => _savingIds.add(key));
    try {
      final existing = _savedIds[key];
      if (existing != null) {
        await _db.collection('savedEvents').doc(existing).delete();
        setState(() => _savedIds.remove(key));
      } else {
        final data = item.data;
        final ref = await _db.collection('savedEvents').add({
          'userId': uid,
          'eventId': item.id,
          'source': item.source,
          'title': data['title'] ?? data['role'],
          'date': data['date'] ?? data['deadline'],
          'type': item.source == 'internship' ? 'internship' : data['type'],
          'description': data['description'],
          'location': data['location'],
          'companyName': data['company'] ?? data['companyName'],
          'savedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _savedIds[key] = ref.id);
      }
      if (mounted) NotificationService.sync(context.read<AuthService>());
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not update bookmark', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingIds.remove(key));
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

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.accent)),
                const SizedBox(height: 5),
                Text(firstName,
                    style: AppTheme.display(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.7,
                        color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text(
                  'Here is what is happening on campus',
                  style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Today's events → Calendar (ink hero card) ──
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: Builder(builder: (context) {
              final brightness = Theme.of(context).brightness;
              final fg = AppColors.onGlossy(brightness);
              final fgMuted = fg.withValues(alpha: 0.55);
              return PressableScale(
                onTap: () => widget.onNavigate('calendar'),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.glossy(brightness),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: fg.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(Icons.calendar_today_outlined,
                                size: 14, color: fg),
                          ),
                          const SizedBox(width: 10),
                          Text("Today's Events",
                              style: AppTheme.display(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: fg)),
                          const SizedBox(width: 8),
                          Text(formatDayDate(DateTime.now()),
                              style:
                                  TextStyle(fontSize: 11, color: fgMuted)),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: fgMuted),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_todayEvents.isEmpty)
                        Text('No events scheduled for today',
                            style:
                                TextStyle(fontSize: 12.5, color: fgMuted))
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
                              color: fg.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: color),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(
                                        text:
                                            AppColors.eventTypeLabel(type),
                                        style: TextStyle(
                                            color: fg,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5),
                                      ),
                                      TextSpan(
                                        text: ' — ${e['title'] ?? ''}',
                                        style: TextStyle(
                                            fontSize: 12.5, color: fg),
                                      ),
                                    ]),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (date != null)
                                  Text(formatTime(date),
                                      style: TextStyle(
                                          fontSize: 11, color: fgMuted)),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            }),
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
            ..._feed.indexed.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFeedCard(entry.$1, entry.$2),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeedCard(int index, _FeedItem item) {
    final card = EventPostCard(
      eventId: item.id,
      data: item.data,
      source: item.source,
      trending: _trendingKeys.contains(item.key),
      saved: _savedIds.containsKey(item.key),
      saving: _savingIds.contains(item.key),
      onToggleSave: () => _toggleSave(item),
      applied: item.source == 'event' && _appliedEventIds.contains(item.id),
      onNavigate: widget.onNavigate,
      onOpenDetail: item.source == 'internship'
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      InternshipDetailScreen(internshipId: item.id),
                ),
              )
          : null,
    );
    // Stagger only the first few cards so refreshes stay snappy.
    if (index > 5) return card;
    return FadeSlideIn(
      delay: Duration(milliseconds: 100 + index * 45),
      child: card,
    );
  }
}
