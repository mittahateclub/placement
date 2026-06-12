import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import '../screens/student/resume_builder_screen.dart';
import '../services/auth_service.dart';
import '../services/event_application_service.dart';
import 'common.dart';
import 'loading_dots.dart';

/// Feed post for an event — image (when the link scrape found one),
/// caption-style description, comments, save and apply.
class EventPostCard extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final bool trending;
  final bool saved;
  final bool saving;
  final VoidCallback onToggleSave;

  /// Whether this student already applied in-app (link-less events).
  final bool applied;

  /// Tab navigation from the home shell (used by Generate Resume).
  final void Function(String id)? onNavigate;

  const EventPostCard({
    super.key,
    required this.eventId,
    required this.data,
    required this.trending,
    required this.saved,
    required this.saving,
    required this.onToggleSave,
    this.applied = false,
    this.onNavigate,
  });

  @override
  State<EventPostCard> createState() => _EventPostCardState();
}

class _EventPostCardState extends State<EventPostCard> {
  bool _expanded = false;
  int? _commentCount;
  bool _applied = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    _loadCommentCount();
  }

  Future<void> _loadCommentCount() async {
    try {
      final agg = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('comments')
          .count()
          .get();
      if (mounted) setState(() => _commentCount = agg.count ?? 0);
    } catch (_) {
      // Counts are cosmetic — ignore failures (e.g. offline).
    }
  }

  Future<void> _openComments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => EventCommentsSheet(eventId: widget.eventId),
    );
    _loadCommentCount();
  }

  Future<void> _apply() async {
    final link = (widget.data['link'] as String?)?.trim();
    if (link != null && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri == null) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showAppSnack(context, 'Could not open the link.', error: true);
      }
      return;
    }
    // No external link — record the application in-app so the admin can see
    // who applied.
    if (_applied || widget.applied || _applying) return;
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    setState(() => _applying = true);
    try {
      await EventApplicationService.apply(
          eventId: widget.eventId, eventData: widget.data, auth: auth);
      if (mounted) {
        setState(() => _applied = true);
        showAppSnack(context, 'Applied! The placement cell can see your application.');
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not apply.', error: true);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  void _generateResume() {
    final data = widget.data;
    final title = (data['title'] as String?) ?? '';
    final location = ((data['location'] as String?) ?? '').trim();
    final description = ((data['description'] as String?) ?? '').trim();
    ResumePrefill.set(
      company: ((data['company'] as String?) ?? '').trim().isNotEmpty
          ? (data['company'] as String).trim()
          : title,
      jobDescription: [
        title,
        if (location.isNotEmpty) 'Location: $location',
        description,
      ].join('\n'),
    );
    widget.onNavigate?.call('resume-builder');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = widget.data;

    final title = (data['title'] as String?) ?? 'Untitled';
    final type = (data['type'] as String?) ?? 'event';
    final description = ((data['description'] as String?) ?? '').trim();
    final imageUrl = (data['imageUrl'] as String?)?.trim();
    final link = (data['link'] as String?)?.trim();
    final location = ((data['location'] as String?) ?? '').trim();
    final date = toDate(data['date']);
    final expiry = toDate(data['expiresAt']) ?? date;

    final now = DateTime.now();
    final expired = expiry != null &&
        expiry.isBefore(DateTime(now.year, now.month, now.day));
    final expiringSoon =
        !expired && expiry != null && expiry.difference(now).inHours < 48;

    final meta = [
      if (location.isNotEmpty) location,
      if (date != null) formatDayDate(date),
    ].join('  ·  ');

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top strip: trending + expiry ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                if (widget.trending) ...[
                  const Pill(
                      label: 'Trending',
                      color: AppColors.pink,
                      icon: Icons.local_fire_department_rounded),
                  const SizedBox(width: 8),
                ],
                const Spacer(),
                if (expiry != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12,
                          color: (expired || expiringSoon)
                              ? AppColors.danger
                              : scheme.onSurface.withValues(alpha: 0.45)),
                      const SizedBox(width: 4),
                      Text(
                        expired
                            ? 'Expired ${formatDate(expiry)}'
                            : 'Apply by ${formatDate(expiry)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (expired || expiringSoon)
                              ? AppColors.danger
                              : scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // ── Title + type ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 5,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2)),
                TypeBadge(type: type),
              ],
            ),
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text(meta,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurface.withValues(alpha: 0.45))),
            ),
          // ── Image (only when the scrape found one) ──
          if (imageUrl != null && imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 200,
                        color: scheme.surfaceContainerLow,
                        alignment: Alignment.center,
                        child: const LoadingDots(size: 6),
                      ),
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          // ── Caption ──
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      maxLines: _expanded ? null : 3,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: scheme.onSurface.withValues(alpha: 0.75)),
                    ),
                    if (description.length > 140)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          _expanded ? 'less' : 'more',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // ── Actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 10, 6),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _openComments,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurface.withValues(alpha: 0.55),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: Text(
                    _commentCount == null || _commentCount == 0
                        ? 'Comment'
                        : '$_commentCount',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: widget.saving ? null : widget.onToggleSave,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    widget.saved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_outline_rounded,
                    size: 19,
                    color: widget.saved
                        ? AppColors.blue
                        : scheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                const Spacer(),
                if (widget.onNavigate != null) ...[
                  OutlinedButton.icon(
                    onPressed: _generateResume,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6),
                    ),
                    icon: const Icon(Icons.description_outlined, size: 13),
                    label: const Text('RESUME'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (link != null && link.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 13),
                    label: const Text('APPLY'),
                  )
                else if (_applied || widget.applied)
                  FilledButton.icon(
                    onPressed: null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      disabledBackgroundColor:
                          AppColors.success.withValues(alpha: 0.15),
                      disabledForegroundColor: AppColors.success,
                      textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 14),
                    label: const Text('APPLIED'),
                  )
                else
                  FilledButton.icon(
                    onPressed: _applying ? null : _apply,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6),
                    ),
                    icon: _applying
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 13),
                    label: const Text('APPLY'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the live comment thread + composer.
class EventCommentsSheet extends StatefulWidget {
  final String eventId;
  const EventCommentsSheet({super.key, required this.eventId});

  @override
  State<EventCommentsSheet> createState() => _EventCommentsSheetState();
}

class _EventCommentsSheetState extends State<EventCommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  CollectionReference<Map<String, dynamic>> get _comments =>
      FirebaseFirestore.instance
          .collection('events')
          .doc(widget.eventId)
          .collection('comments');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    setState(() => _sending = true);
    try {
      await _comments.add({
        'userId': uid,
        'userName': auth.userName ?? auth.user?.email ?? 'Student',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _controller.clear();
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not post the comment.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Comments',
                  style:
                      TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ),
            Divider(color: scheme.outline),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _comments
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Comments unavailable',
                          style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4))),
                    );
                  }
                  if (!snap.hasData) return const CenteredLoader();
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text('Be the first to comment',
                          style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4))),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final c = docs[i].data();
                      final name = (c['userName'] as String?) ?? 'Student';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.15),
                              child: Text(
                                name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(timeAgo(toDate(c['createdAt'])),
                                          style: TextStyle(
                                              fontSize: 10.5,
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.35))),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text((c['text'] as String?) ?? '',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          height: 1.4,
                                          color: scheme.onSurface
                                              .withValues(alpha: 0.8))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Divider(color: scheme.outline, height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(hintText: 'Add a comment…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: Icon(Icons.send_rounded,
                        size: 20, color: scheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
