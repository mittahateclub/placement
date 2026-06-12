import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../core/student_filters.dart';
import '../../models/college_item.dart';
import '../../services/auth_service.dart';
import '../../services/event_application_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'internship_detail_screen.dart';
import 'resume_builder_screen.dart';

/// One-shot handoff: the calendar sets an event id here before switching to
/// the College tab, and College Space pins + highlights that event on open.
class CollegeSpaceFocus {
  static String? eventId;
}

/// All events + internships from the university, with search & bookmarks
/// (mirrors the web "College Space" page).
class CollegeSpaceScreen extends StatefulWidget {
  final void Function(String id)? onNavigate;
  const CollegeSpaceScreen({super.key, this.onNavigate});

  @override
  State<CollegeSpaceScreen> createState() => _CollegeSpaceScreenState();
}

class _CollegeSpaceScreenState extends State<CollegeSpaceScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  List<CollegeItem> _items = [];
  final Map<String, String> _savedIds = {}; // saveKey -> savedEvents doc id
  final Set<String> _savingKeys = {};
  Set<String> _appliedEventIds = {};
  final Set<String> _applyingIds = {};
  String _query = '';
  bool _showSaved = false;
  String? _focusEventId;

  @override
  void initState() {
    super.initState();
    _focusEventId = CollegeSpaceFocus.eventId;
    CollegeSpaceFocus.eventId = null;
    _fetch();
  }

  Future<void> _fetch() async {
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    try {
      final universityId = auth.universityId;
      final results = await Future.wait([
        _db.collection('events').get(),
        universityId == null
            ? Future.value(null)
            : _db
                .collection('internships')
                .where('universityId', isEqualTo: universityId)
                .get(),
        _db.collection('savedEvents').where('userId', isEqualTo: uid).get(),
        EventApplicationService.appliedEventIds(uid),
      ]);

      // Students never see expired listings, and events respect their
      // branch / GPA targeting.
      final now = DateTime.now();
      final all = <CollegeItem>[
        ...(results[0] as QuerySnapshot<Map<String, dynamic>>)
            .docs
            .map(CollegeItem.fromEvent)
            .where((e) =>
                (e.effectiveExpiry == null ||
                    now.isBefore(e.effectiveExpiry!)) &&
                eventTargetsStudent(e.raw,
                    branch: auth.branch, gpa: auth.gpa)),
        if (results[1] != null)
          ...(results[1] as QuerySnapshot<Map<String, dynamic>>)
              .docs
              .map(CollegeItem.fromInternship)
              .where((i) =>
                  i.effectiveExpiry == null ||
                  now.isBefore(i.effectiveExpiry!)),
      ]..sort((a, b) => (a.date?.millisecondsSinceEpoch ?? 0)
          .compareTo(b.date?.millisecondsSinceEpoch ?? 0));

      // An event opened from the calendar floats to the top, highlighted.
      if (_focusEventId != null) {
        final i = all.indexWhere(
            (e) => e.source == 'event' && e.id == _focusEventId);
        if (i > 0) all.insert(0, all.removeAt(i));
      }

      _savedIds.clear();
      for (final d
          in (results[2] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final data = d.data();
        _savedIds['${data['source']}-${data['eventId']}'] = d.id;
      }

      if (mounted) {
        setState(() {
          _items = all;
          _appliedEventIds = results[3] as Set<String>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showAppSnack(context, 'Failed to load College Space', error: true);
      }
    }
  }

  Future<void> _applyTo(CollegeItem item) async {
    final auth = context.read<AuthService>();
    final link = item.link;
    if (link != null && link.isNotEmpty) {
      final uri = Uri.tryParse(link);
      if (uri == null) return;
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showAppSnack(context, 'Could not open the link.', error: true);
      }
      return;
    }
    if (_appliedEventIds.contains(item.id) ||
        _applyingIds.contains(item.id)) {
      return;
    }
    setState(() => _applyingIds.add(item.id));
    try {
      await EventApplicationService.apply(
          eventId: item.id, eventData: item.raw, auth: auth);
      if (mounted) {
        setState(() => _appliedEventIds.add(item.id));
        showAppSnack(
            context, 'Applied! The placement cell can see your application.');
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not apply.', error: true);
    } finally {
      if (mounted) setState(() => _applyingIds.remove(item.id));
    }
  }

  void _generateResume(CollegeItem item) {
    ResumePrefill.set(
      company: (item.companyName?.isNotEmpty ?? false)
          ? item.companyName
          : item.title,
      jobDescription: [
        item.title,
        if (item.location?.isNotEmpty ?? false) 'Location: ${item.location}',
        item.description,
      ].join('\n'),
    );
    widget.onNavigate?.call('resume-builder');
  }

  Future<void> _toggleSave(CollegeItem item) async {
    final auth = context.read<AuthService>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    final key = item.saveKey;
    setState(() => _savingKeys.add(key));
    try {
      if (_savedIds.containsKey(key)) {
        await _db.collection('savedEvents').doc(_savedIds[key]).delete();
        setState(() => _savedIds.remove(key));
      } else {
        final ref = await _db.collection('savedEvents').add({
          'userId': uid,
          'eventId': item.id,
          'source': item.source,
          'title': item.title,
          'date': item.date != null ? Timestamp.fromDate(item.date!) : null,
          'type': item.type,
          'description': item.description,
          'location': item.location,
          'companyName': item.companyName,
          'savedAt': FieldValue.serverTimestamp(),
        });
        setState(() => _savedIds[key] = ref.id);
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Could not update bookmark', error: true);
    } finally {
      if (mounted) setState(() => _savingKeys.remove(key));
    }
  }

  List<CollegeItem> get _filtered {
    var list = _items;
    if (_showSaved) {
      list = list.where((i) => _savedIds.containsKey(i.saveKey)).toList();
    }
    if (_query.trim().isNotEmpty) {
      list = list.where((i) => i.matches(_query)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;
    final items = _filtered;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageHeader(
            title: 'College Space',
            subtitle: 'All events, internships & opportunities from your university',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search events, companies, locations...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _showSaved
                    ? AppColors.blue.withValues(alpha: 0.12)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _showSaved = !_showSaved),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _showSaved
                              ? AppColors.blue.withValues(alpha: 0.4)
                              : scheme.outline),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_outline_rounded,
                          size: 16,
                          color: _showSaved
                              ? AppColors.blue
                              : scheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${_savedIds.length}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _showSaved
                                ? AppColors.blue
                                : scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const EmptyState(
              icon: Icons.school_outlined,
              title: 'No listings found',
              subtitle: 'Check back for new opportunities',
            )
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ListingCard(
                    item: item,
                    saved: _savedIds.containsKey(item.saveKey),
                    saving: _savingKeys.contains(item.saveKey),
                    onToggleSave: () => _toggleSave(item),
                    highlighted:
                        item.source == 'event' && item.id == _focusEventId,
                    applied: item.source == 'event' &&
                        _appliedEventIds.contains(item.id),
                    applying: _applyingIds.contains(item.id),
                    onApply:
                        item.source == 'event' ? () => _applyTo(item) : null,
                    onGenerateResume: item.source == 'event' &&
                            widget.onNavigate != null
                        ? () => _generateResume(item)
                        : null,
                    onOpen: item.source == 'internship'
                        ? () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InternshipDetailScreen(
                                    internshipId: item.id),
                              ),
                            )
                        : null,
                  ),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final CollegeItem item;
  final bool saved;
  final bool saving;
  final VoidCallback onToggleSave;
  final VoidCallback? onOpen;
  final bool highlighted;
  final bool applied;
  final bool applying;
  final VoidCallback? onApply;
  final VoidCallback? onGenerateResume;

  const _ListingCard({
    required this.item,
    required this.saved,
    required this.saving,
    required this.onToggleSave,
    this.onOpen,
    this.highlighted = false,
    this.applied = false,
    this.applying = false,
    this.onApply,
    this.onGenerateResume,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = item.date;

    final card = SurfaceCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date badge
          if (d != null)
            Container(
              width: 44,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                children: [
                  Text('${d.day}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(
                    formatDate(d).split(' ').first.toUpperCase(),
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: scheme.onSurface.withValues(alpha: 0.35)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TypeBadge(type: item.type),
                    if (item.companyName != null)
                      Text(item.companyName!,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accent)),
                  ],
                ),
                const SizedBox(height: 7),
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700)),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (d != null)
                      _Meta(icon: Icons.schedule_rounded, text: '${formatDayDate(d)} · ${formatTime(d)}'),
                    if (item.location != null && item.location!.isNotEmpty)
                      _Meta(icon: Icons.place_outlined, text: item.location!),
                    if (item.stipend != null && item.stipend!.isNotEmpty)
                      _Meta(
                          icon: Icons.payments_outlined,
                          text: item.stipend!,
                          color: AppColors.success),
                    if (item.duration != null && item.duration!.isNotEmpty)
                      _Meta(
                          icon: Icons.timelapse_rounded, text: item.duration!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            children: [
              IconButton(
                onPressed: saving ? null : onToggleSave,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  size: 20,
                  color: saved
                      ? AppColors.blue
                      : scheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              if (onOpen != null)
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: scheme.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ],
      ),
          // ── Event actions: tailor a resume + apply ──
          if (onApply != null || onGenerateResume != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onGenerateResume != null) ...[
                  OutlinedButton.icon(
                    onPressed: onGenerateResume,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6),
                    ),
                    icon: const Icon(Icons.description_outlined, size: 13),
                    label: const Text('RESUME'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onApply != null)
                  applied
                      ? FilledButton.icon(
                          onPressed: null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            disabledBackgroundColor:
                                AppColors.success.withValues(alpha: 0.15),
                            disabledForegroundColor: AppColors.success,
                            textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('APPLIED'),
                        )
                      : FilledButton.icon(
                          onPressed: applying ? null : onApply,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6),
                          ),
                          icon: applying
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Icon(
                                  (item.link?.isNotEmpty ?? false)
                                      ? Icons.open_in_new_rounded
                                      : Icons.send_rounded,
                                  size: 13),
                          label: const Text('APPLY'),
                        ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!highlighted) return card;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      child: card,
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Meta({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final base = color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: base),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: base)),
      ],
    );
  }
}
