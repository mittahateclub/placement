import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

class StudentDashboard extends StatefulWidget {
  final void Function(String id) onNavigate;
  const StudentDashboard({super.key, required this.onNavigate});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  bool _loading = true;
  List<Map<String, dynamic>> _todayEvents = [];

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
      final snap = await FirebaseFirestore.instance
          .collection('savedEvents')
          .where('userId', isEqualTo: uid)
          .get();
      final today = DateTime.now();
      final events = snap.docs
          .map((d) => d.data())
          .where((d) {
            final date = toDate(d['date']);
            return date != null && sameDay(date, today);
          })
          .toList();
      if (mounted) {
        setState(() {
          _todayEvents = events;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();

    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;
    final firstName =
        (auth.userName ?? auth.user?.email ?? 'Student').split(RegExp(r'[ @]')).first;

    final cards = [
      _MenuCard(
        title: 'College Space',
        desc: 'Explore events, internships and campus opportunities',
        icon: Icons.business_center_outlined,
        onTap: () => widget.onNavigate('college'),
      ),
      _MenuCard(
        title: 'Applications',
        desc: 'Track your submissions and statuses in one place',
        icon: Icons.assignment_turned_in_outlined,
        onTap: () => widget.onNavigate('applications'),
      ),
      _MenuCard(
        title: 'AI Resume Builder',
        desc: 'Craft a professional resume with AI suggestions',
        icon: Icons.auto_awesome_outlined,
        onTap: () => widget.onNavigate('resume-builder'),
      ),
      _MenuCard(
        title: 'Export Resume',
        desc: 'Download your polished resume as a print-ready PDF',
        icon: Icons.picture_as_pdf_outlined,
        onTap: () => widget.onNavigate('my-resumes'),
      ),
      _MenuCard(
        title: 'Results',
        desc: 'View scores, percentiles and performance breakdowns',
        icon: Icons.insights_outlined,
        onTap: () => widget.onNavigate('results'),
      ),
      _MenuCard(
        title: 'Profile',
        desc: 'Manage your academic details and portfolio',
        icon: Icons.person_outline_rounded,
        onTap: () => widget.onNavigate('profile'),
      ),
    ];

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
            'Here is what is happening today',
            style: TextStyle(
                fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 18),

          // ── Today's events ──
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
                        border:
                            Border.all(color: color.withValues(alpha: 0.3)),
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
          const SizedBox(height: 16),

          // ── Quick access grid ──
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.18,
            children: cards,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final String desc;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: scheme.outline),
            ),
            child: Icon(icon, size: 17, color: AppColors.accent),
          ),
          const Spacer(),
          Text(title,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5,
                height: 1.35,
                color: scheme.onSurface.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}
