import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

class _CalEvent {
  final String id;
  final String title;
  final DateTime? date;
  final String type;
  final String description;
  final String? location;
  final String? company;

  _CalEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.type,
    required this.description,
    this.location,
    this.company,
  });
}

/// Month calendar of the student's saved events (bookmarks become
/// calendar entries — same model as the website).
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  bool _loading = true;
  List<_CalEvent> _events = [];
  late DateTime _currentMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
    _fetch();
  }

  Future<void> _fetch() async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('savedEvents')
          .where('userId', isEqualTo: uid)
          .get();
      final events = snap.docs.map((d) {
        final data = d.data();
        return _CalEvent(
          id: d.id,
          title: (data['title'] as String?) ?? 'Untitled',
          date: toDate(data['date']),
          type: (data['type'] as String?) ?? 'event',
          description: (data['description'] as String?) ?? '',
          location: data['location'] as String?,
          company: data['companyName'] as String?,
        );
      }).toList();
      if (mounted) {
        setState(() {
          _events = events;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_CalEvent> _eventsOn(DateTime date) => _events
      .where((e) => e.date != null && sameDay(e.date!, date))
      .toList();

  List<_CalEvent> get _upcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cutoff = today.add(const Duration(days: 30));
    final list = _events
        .where((e) =>
            e.date != null && !e.date!.isBefore(today) && e.date!.isBefore(cutoff))
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));
    return list.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();

    // Build month grid cells
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < firstWeekday; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_currentMonth.year, _currentMonth.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final selectedEvents =
        _selectedDate != null ? _eventsOn(_selectedDate!) : <_CalEvent>[];

    final monthEvents = _events
        .where((e) =>
            e.date != null &&
            e.date!.year == _currentMonth.year &&
            e.date!.month == _currentMonth.month)
        .toList();

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHeader(
            title: 'Calendar',
            subtitle: 'Your saved events, deadlines & opportunities',
            trailing: OutlinedButton(
              onPressed: () => setState(() {
                _currentMonth = DateTime(today.year, today.month, 1);
                _selectedDate = today;
              }),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14)),
              child: const Text('Today'),
            ),
          ),
          const SizedBox(height: 16),

          // ── Month grid ──
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        onPressed: () => setState(() => _currentMonth = DateTime(
                            _currentMonth.year, _currentMonth.month - 1, 1)),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat('MMMM yyyy').format(_currentMonth),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                        onPressed: () => setState(() => _currentMonth = DateTime(
                            _currentMonth.year, _currentMonth.month + 1, 1)),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          for (final d in const [
                            'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
                          ])
                            Expanded(
                              child: Center(
                                child: Text(
                                  d.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.35)),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (var w = 0; w < cells.length ~/ 7; w++)
                        Row(
                          children: [
                            for (var i = 0; i < 7; i++)
                              Expanded(
                                child: _DayCell(
                                  date: cells[w * 7 + i],
                                  events: cells[w * 7 + i] == null
                                      ? const []
                                      : _eventsOn(cells[w * 7 + i]!),
                                  isToday: cells[w * 7 + i] != null &&
                                      sameDay(cells[w * 7 + i]!, today),
                                  isSelected: cells[w * 7 + i] != null &&
                                      _selectedDate != null &&
                                      sameDay(
                                          cells[w * 7 + i]!, _selectedDate!),
                                  onTap: cells[w * 7 + i] == null
                                      ? null
                                      : () => setState(() {
                                            final c = cells[w * 7 + i]!;
                                            _selectedDate = _selectedDate !=
                                                        null &&
                                                    sameDay(
                                                        c, _selectedDate!)
                                                ? null
                                                : c;
                                          }),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Selected day detail ──
          if (_selectedDate != null) ...[
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(formatDayDate(_selectedDate),
                          style: const TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 16),
                        onPressed: () => setState(() => _selectedDate = null),
                      ),
                    ],
                  ),
                  if (selectedEvents.isEmpty)
                    Text('No events on this day',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurface.withValues(alpha: 0.4)))
                  else
                    ...selectedEvents.map((e) => _EventTile(event: e)),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── Upcoming ──
          const FieldLabel('Upcoming (next 30 days)'),
          if (_upcoming.isEmpty)
            const EmptyState(
              icon: Icons.event_outlined,
              title: 'No upcoming events',
              subtitle: 'Save events from College Space to see them here',
            )
          else
            ..._upcoming.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SurfaceCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => setState(() {
                      _currentMonth =
                          DateTime(e.date!.year, e.date!.month, 1);
                      _selectedDate = e.date;
                    }),
                    child: _EventTile(event: e, compact: true),
                  ),
                )),
          const SizedBox(height: 16),

          // ── Month summary ──
          const FieldLabel('This Month'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: AppColors.eventTypeColors.entries.map((entry) {
              final count =
                  monthEvents.where((e) => e.type == entry.key).length;
              return SurfaceCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: entry.value, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${AppColors.eventTypeLabel(entry.key)}s'
                            .toUpperCase(),
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color:
                                scheme.onSurface.withValues(alpha: 0.4)),
                      ),
                    ),
                    Text('$count',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime? date;
  final List<_CalEvent> events;
  final bool isToday;
  final bool isSelected;
  final VoidCallback? onTap;

  const _DayCell({
    required this.date,
    required this.events,
    required this.isToday,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (date == null) return const SizedBox(height: 46);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.blue.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? AppColors.accent
                    : isSelected
                        ? AppColors.blue
                        : Colors.transparent,
              ),
              child: Text(
                '${date!.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: (isToday || isSelected)
                      ? Colors.white
                      : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final e in events.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: AppColors.eventTypeColor(e.type),
                        shape: BoxShape.circle,
                      ),
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

class _EventTile extends StatelessWidget {
  final _CalEvent event;
  final bool compact;

  const _EventTile({required this.event, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppColors.eventTypeColor(event.type);

    return Container(
      margin: EdgeInsets.only(bottom: compact ? 0 : 8),
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: compact
          ? null
          : BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact && event.date != null)
            Container(
              width: 36,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                children: [
                  Text('${event.date!.day}',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(
                    DateFormat('MMM').format(event.date!).toUpperCase(),
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: scheme.onSurface.withValues(alpha: 0.35)),
                  ),
                ],
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.info_outline_rounded, size: 14, color: color),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: AppColors.eventTypeLabel(event.type),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color),
                    ),
                    TextSpan(
                      text: ' — ${event.title}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  children: [
                    if (event.date != null)
                      Text(formatTime(event.date),
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4))),
                    if (event.location != null)
                      Text('📍 ${event.location}',
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4))),
                    if (event.company != null)
                      Text('🏢 ${event.company}',
                          style: TextStyle(
                              fontSize: 10,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
