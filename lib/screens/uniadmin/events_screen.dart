import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

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
  final _location = TextEditingController();
  final _description = TextEditingController();
  String _type = 'event';
  DateTime? _dateTime;

  bool _submitting = false;
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
    _location.dispose();
    _description.dispose();
    super.dispose();
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
        'description': _description.text.trim(),
        'date': Timestamp.fromDate(_dateTime!),
        'location': _location.text.trim(),
        'type': _type,
        'universityId': universityId,
        'createdBy': auth.user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'attendees': [],
      });
      if (mounted) {
        showAppSnack(context, 'Event created successfully!');
        _title.clear();
        _location.clear();
        _description.clear();
        setState(() {
          _type = 'event';
          _dateTime = null;
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
                const FieldLabel('Event Title *'),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(hintText: 'Event title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'POSTING…' : 'POST EVENT'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Existing events ──
        const FieldLabel('Existing Events'),
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
          ..._events.map((entry) {
            final (id, data) = entry;
            final d = toDate(data['date']);
            final type = (data['type'] as String?) ?? 'event';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SurfaceCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (d != null)
                      Container(
                        width: 40,
                        margin: const EdgeInsets.only(right: 10),
                        child: Column(
                          children: [
                            Text('${d.day}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            Text(
                              DateFormat('MMM').format(d).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.35)),
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
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text((data['location'] as String?) ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.4))),
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
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _delete(id),
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.4)),
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
