import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/format.dart';
import '../../core/student_filters.dart';
import '../../services/auth_service.dart';
import '../../services/event_scraper.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'event_applicants_screen.dart';

/// Create new events and manage existing ones (type changes, deletion) —
/// matches the web "Manage Events" page including the internships type.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _link = TextEditingController();
  String _type = 'event';
  DateTime? _dateTime;
  DateTime? _expiry;

  // Audience targeting: empty set = all branches; null = any GPA.
  final Set<String> _targetBranches = {};
  double? _minGpa;
  String? _scrapedImageUrl;
  String? _scrapeNote;
  bool _scrapeError = false;

  bool _submitting = false;
  bool _scraping = false;
  bool _loadingEvents = true;
  List<(String, Map<String, dynamic>)> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _location.dispose();
    _description.dispose();
    _link.dispose();
    super.dispose();
  }

  /// Scrapes the pasted link and auto-fills the form. The image is only
  /// attached when the page actually exposes one.
  Future<void> _scrapeLink() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _scraping = true;
      _scrapeNote = null;
      _scrapeError = false;
    });
    try {
      final result = await EventScraper.scrape(_link.text);
      if (!mounted) return;
      setState(() {
        if (result.title != null) _title.text = result.title!;
        if (result.company != null) _company.text = result.company!;
        if (result.description != null) {
          _description.text = result.description!;
        }
        if (result.location != null) _location.text = result.location!;
        if (result.type != null) _type = result.type!;
        if (result.deadline != null) _expiry = result.deadline;
        _scrapedImageUrl = result.imageUrl;
        _scrapeNote = result.imageUrl != null
            ? 'Details and image pulled from the page — review below.'
            : 'Details filled. No image on the page, so the post will be text-only.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _scrapeNote = e.toString().replaceFirst('Exception: ', '');
          _scrapeError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _scraping = false);
    }
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiry ?? _dateTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date != null) setState(() => _expiry = date);
  }

  Future<void> _fetchEvents() async {
    final universityId = context.read<AuthService>().universityId;
    if (universityId == null) {
      setState(() => _loadingEvents = false);
      return;
    }
    try {
      final snap = await _db
          .collection('events')
          .where('universityId', isEqualTo: universityId)
          .get();
      final list = snap.docs.map((d) => (d.id, d.data())).toList()
        ..sort((a, b) => (toDate(b.$2['date'])?.millisecondsSinceEpoch ?? 0)
            .compareTo(toDate(a.$2['date'])?.millisecondsSinceEpoch ?? 0));
      if (mounted) {
        setState(() {
          _events = list;
          _loadingEvents = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dateTime != null
          ? TimeOfDay.fromDateTime(_dateTime!)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;
    setState(() => _dateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    final universityId = auth.universityId;
    if (universityId == null) {
      showAppSnack(context, 'Profile error: University ID not found.',
          error: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dateTime == null) {
      showAppSnack(context, 'Please pick a date & time.', error: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await _db.collection('events').add({
        'title': _title.text.trim(),
        'company':
            _company.text.trim().isEmpty ? null : _company.text.trim(),
        'description': _description.text.trim(),
        'date': Timestamp.fromDate(_dateTime!),
        'location': _location.text.trim(),
        'type': _type,
        'universityId': universityId,
        'createdBy': auth.user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'attendees': [],
        'link': _link.text.trim().isEmpty ? null : _link.text.trim(),
        'imageUrl': _scrapedImageUrl,
        'expiresAt': _expiry != null ? Timestamp.fromDate(_expiry!) : null,
        // Audience: ['all'] or specific branches; minGpa null = everyone.
        'targetBranches':
            _targetBranches.isEmpty ? ['all'] : _targetBranches.toList(),
        'minGpa': _minGpa,
      });
      if (mounted) {
        showAppSnack(context, 'Event created successfully!');
        _title.clear();
        _company.clear();
        _location.clear();
        _description.clear();
        _link.clear();
        setState(() {
          _type = 'event';
          _dateTime = null;
          _expiry = null;
          _scrapedImageUrl = null;
          _targetBranches.clear();
          _minGpa = null;
        });
        _fetchEvents();
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Failed to create event.', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Effective end date of an event (apply-by wins over the event date).
  static DateTime? _expiryOf(Map<String, dynamic> data) {
    final d = toDate(data['expiresAt']) ?? toDate(data['date']);
    return d == null
        ? null
        : DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  /// Lets the admin extend/correct the event date and expiry — mainly for
  /// expired events still inside the 10-day grace window.
  Future<void> _editDates(String eventId, Map<String, dynamic> data) async {
    var date = toDate(data['date']);
    var expiry = toDate(data['expiresAt']);
    final now = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Edit dates',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Event date & time'),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today_outlined, size: 14),
                label: Text(
                    date == null ? 'Select' : formatDateTime(date),
                    style: const TextStyle(fontSize: 12.5)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: date ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 3),
                  );
                  if (d == null || !context.mounted) return;
                  final t = await showTimePicker(
                    context: context,
                    initialTime: date != null
                        ? TimeOfDay.fromDateTime(date!)
                        : const TimeOfDay(hour: 10, minute: 0),
                  );
                  if (t == null) return;
                  setLocal(() => date =
                      DateTime(d.year, d.month, d.day, t.hour, t.minute));
                },
              ),
              const SizedBox(height: 12),
              const FieldLabel('Apply by / expiry'),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded, size: 14),
                label: Text(
                    expiry == null ? 'Same as event date' : formatDate(expiry),
                    style: const TextStyle(fontSize: 12.5)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: expiry ?? date ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 3),
                  );
                  if (d != null) setLocal(() => expiry = d);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || date == null) return;
    try {
      await _db.collection('events').doc(eventId).update({
        'date': Timestamp.fromDate(date!),
        'expiresAt': expiry != null ? Timestamp.fromDate(expiry!) : null,
      });
      if (mounted) {
        showAppSnack(context, 'Dates updated.');
        _fetchEvents();
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to update dates.', error: true);
      }
    }
  }

  /// Opens the admin's mail app with the event's targeted students BCC'd.
  Future<void> _emailStudents(Map<String, dynamic> data) async {
    final universityId = context.read<AuthService>().universityId;
    if (universityId == null) return;
    try {
      final snap = await _db
          .collection('users')
          .where('universityId', isEqualTo: universityId)
          .get();
      final emails = snap.docs
          .map((d) => d.data())
          .where((u) =>
              (u['role'] == 'student' || u['role'] == 'user') &&
              eventTargetsStudent(data,
                  branch: u['branch'] as String?, gpa: cgpaFromProfile(u)))
          .map((u) => (u['email'] as String?) ?? '')
          .where((e) => e.isNotEmpty)
          .toSet();
      if (emails.isEmpty) {
        if (mounted) {
          showAppSnack(context, 'No matching students with emails found.',
              error: true);
        }
        return;
      }
      final title = (data['title'] as String?) ?? 'New opportunity';
      final uri = Uri(
        scheme: 'mailto',
        path: '',
        query: 'bcc=${emails.join(',')}'
            '&subject=${Uri.encodeComponent(title)}'
            '&body=${Uri.encodeComponent((data['description'] as String?) ?? '')}',
      );
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        showAppSnack(context, 'No email app available.', error: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not load student emails.', error: true);
      }
    }
  }

  Future<void> _updateType(String eventId, String newType) async {
    try {
      await _db.collection('events').doc(eventId).update({'type': newType});
      setState(() {
        _events = _events
            .map((e) =>
                e.$1 == eventId ? (e.$1, {...e.$2, 'type': newType}) : e)
            .toList();
      });
    } catch (_) {
      if (mounted) showAppSnack(context, 'Failed to update type.', error: true);
    }
  }

  Future<void> _delete(String eventId) async {
    final confirmed = await confirmDialog(context,
        title: 'Delete event?',
        message: 'Students will no longer see this in College Space.');
    if (!confirmed) return;
    try {
      await _db.collection('events').doc(eventId).delete();
      setState(() => _events.removeWhere((e) => e.$1 == eventId));
    } catch (_) {
      if (mounted) showAppSnack(context, 'Failed to delete event.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Manage Events',
          subtitle: 'Create new events and manage existing ones',
        ),
        const SizedBox(height: 16),

        // ── Create form ──
        SurfaceCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('Event / Job Link (optional)'),
                TextFormField(
                  controller: _link,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    hintText: 'https://company.com/careers/role',
                    prefixIcon: Icon(Icons.link_rounded, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _scraping ? null : _scrapeLink,
                  icon: _scraping
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded,
                          size: 15, color: AppColors.accent),
                  label: Text(
                      _scraping ? 'Reading page…' : 'Auto-fill from link'),
                ),
                if (_scrapeNote != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: (_scrapeError
                              ? AppColors.danger
                              : AppColors.success)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: (_scrapeError
                                  ? AppColors.danger
                                  : AppColors.success)
                              .withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _scrapeError
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 14,
                          color: _scrapeError
                              ? AppColors.danger
                              : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _scrapeNote!,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: _scrapeError
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_scrapedImageUrl != null) ...[
                  const SizedBox(height: 12),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            _scrapedImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: scheme.surfaceContainerLow,
                              alignment: Alignment.center,
                              child: Icon(Icons.broken_image_outlined,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.3)),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                setState(() => _scrapedImageUrl = null),
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Divider(color: scheme.outline),
                const SizedBox(height: 14),
                const FieldLabel('Event Title *'),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(hintText: 'Event title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Company / Organizer (optional)'),
                TextFormField(
                  controller: _company,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Google, IEEE chapter…'),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Type'),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  items: AppColors.eventTypeColors.keys
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(AppColors.eventTypeLabel(t),
                                style: const TextStyle(fontSize: 13.5)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? 'event'),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Date & Time *'),
                OutlinedButton.icon(
                  onPressed: _pickDateTime,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(
                    _dateTime == null
                        ? 'Select date & time'
                        : formatDateTime(_dateTime),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _dateTime == null
                          ? scheme.onSurface.withValues(alpha: 0.4)
                          : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Apply By / Expiry (optional)'),
                OutlinedButton.icon(
                  onPressed: _pickExpiry,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                  icon: const Icon(Icons.hourglass_bottom_rounded, size: 15),
                  label: Text(
                    _expiry == null
                        ? 'Select expiry date'
                        : formatDate(_expiry),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _expiry == null
                          ? scheme.onSurface.withValues(alpha: 0.4)
                          : scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Location *'),
                TextFormField(
                  controller: _location,
                  decoration: const InputDecoration(hintText: 'Location'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Description *'),
                TextFormField(
                  controller: _description,
                  maxLines: 4,
                  decoration: const InputDecoration(hintText: 'Description'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Divider(color: scheme.outline),
                const SizedBox(height: 14),

                // ── Audience targeting ──
                const FieldLabel('Send to branches'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      selected: _targetBranches.isEmpty,
                      onSelected: (_) =>
                          setState(() => _targetBranches.clear()),
                      label: const Text('All students',
                          style: TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w700)),
                      visualDensity: VisualDensity.compact,
                      showCheckmark: false,
                      selectedColor:
                          AppColors.accent.withValues(alpha: 0.15),
                    ),
                    for (final b in kBranches)
                      FilterChip(
                        selected: _targetBranches.contains(b),
                        onSelected: (sel) => setState(() => sel
                            ? _targetBranches.add(b)
                            : _targetBranches.remove(b)),
                        label: Text(b,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700)),
                        visualDensity: VisualDensity.compact,
                        showCheckmark: false,
                        selectedColor:
                            AppColors.accent.withValues(alpha: 0.15),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const FieldLabel('Minimum CGPA'),
                DropdownButtonFormField<double?>(
                  initialValue: _minGpa,
                  items: [
                    const DropdownMenuItem<double?>(
                      value: null,
                      child: Text('All students (no cutoff)',
                          style: TextStyle(fontSize: 13.5)),
                    ),
                    for (final g in kGpaCutoffs)
                      DropdownMenuItem<double?>(
                        value: g,
                        child: Text('$g and above',
                            style: const TextStyle(fontSize: 13.5)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _minGpa = v),
                ),
                const SizedBox(height: 16),
                GradientButton(
                  label: 'Post Event',
                  icon: Icons.campaign_outlined,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Existing events ──
        // Students stop seeing an event the moment it expires; here it
        // stays editable for a 10-day grace window, then drops off too.
        const SectionHeader('Existing Events'),
        if (_loadingEvents)
          const Padding(
              padding: EdgeInsets.all(24), child: Center(child: LoadingDots()))
        else if (_events.isEmpty)
          const EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'No events yet',
            subtitle: 'Events you post appear here',
          )
        else
          ..._events.where((entry) {
            final expiry = _expiryOf(entry.$2);
            return expiry == null ||
                DateTime.now()
                    .isBefore(expiry.add(const Duration(days: 10)));
          }).map((entry) {
            final (id, data) = entry;
            final d = toDate(data['date']);
            final type = (data['type'] as String?) ?? 'event';
            final expiry = _expiryOf(data);
            final isExpired =
                expiry != null && DateTime.now().isAfter(expiry);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (d != null)
                      Container(
                        width: 42,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color:
                                  scheme.primary.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          children: [
                            Text('${d.day}',
                                style: AppTheme.display(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface)),
                            Text(
                              DateFormat('MMM').format(d).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.5)),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((data['title'] as String?) ?? 'Untitled',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.display(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onSurface)),
                          const SizedBox(height: 2),
                          Text((data['location'] as String?) ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.4))),
                          if (isExpired) ...[
                            const SizedBox(height: 5),
                            Pill(
                                label:
                                    'Expired · editable till ${formatDate(expiry.add(const Duration(days: 10)))}',
                                color: AppColors.amber),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Change type',
                      onSelected: (newType) => _updateType(id, newType),
                      itemBuilder: (_) => AppColors.eventTypeColors.keys
                          .map((t) => PopupMenuItem(
                                value: t,
                                child: Text(AppColors.eventTypeLabel(t),
                                    style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      child: TypeBadge(type: type),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Actions',
                      onSelected: (action) => switch (action) {
                        'applicants' => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventApplicantsScreen(
                                eventId: id,
                                eventTitle:
                                    (data['title'] as String?) ?? 'Event',
                              ),
                            ),
                          ),
                        'email' => _emailStudents(data),
                        'dates' => _editDates(id, data),
                        _ => _delete(id),
                      },
                      icon: Icon(Icons.more_vert_rounded,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.4)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'applicants',
                            child: Text('View applicants',
                                style: TextStyle(fontSize: 13))),
                        PopupMenuItem(
                            value: 'email',
                            child: Text('Email students…',
                                style: TextStyle(fontSize: 13))),
                        PopupMenuItem(
                            value: 'dates',
                            child: Text('Edit dates…',
                                style: TextStyle(fontSize: 13))),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(fontSize: 13))),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 24),
      ],
    );
  }
}
