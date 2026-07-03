import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

class UniadminDashboard extends StatefulWidget {
  final void Function(String id) onNavigate;
  const UniadminDashboard({super.key, required this.onNavigate});

  @override
  State<UniadminDashboard> createState() => _UniadminDashboardState();
}

class _UniadminDashboardState extends State<UniadminDashboard> {
  int? _studentCount;
  int? _eventCount;
  int? _testCount;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final universityId = context.read<AuthService>().universityId;
    if (universityId == null) return;
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('universityId', isEqualTo: universityId)
            .count()
            .get(),
        db
            .collection('events')
            .where('universityId', isEqualTo: universityId)
            .count()
            .get(),
        db
            .collection('tests')
            .where('universityId', isEqualTo: universityId)
            .count()
            .get(),
      ]);
      if (mounted) {
        setState(() {
          _studentCount = results[0].count;
          _eventCount = results[1].count;
          _testCount = results[2].count;
        });
      }
    } catch (_) {
      // Stats are best-effort; cards still navigate.
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;

    final tools = [
      (
        'Manage Tests',
        'Review, approve and share tests with students',
        Icons.quiz_outlined,
        'tests'
      ),
      (
        'Create Event',
        'Post workshops, seminars and campus opportunities',
        Icons.event_outlined,
        'events'
      ),
      (
        'Support Inbox',
        'Student chats handled like tickets — claim and reply',
        Icons.chat_bubble_outline_rounded,
        'inbox'
      ),
      (
        'Register Student',
        'Create student profiles for your university',
        Icons.person_add_outlined,
        'create-account'
      ),
      (
        'Student Database',
        'Browse and manage all registered students',
        Icons.group_outlined,
        'students'
      ),
      (
        'Admin Profile',
        'Your credentials and university details',
        Icons.person_outline_rounded,
        'profile'
      ),
    ];

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FadeSlideIn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UNIVERSITY ADMIN',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.accent)),
                const SizedBox(height: 5),
                Text(
                  'Welcome back, ${(auth.userName ?? auth.user?.email ?? '').split(RegExp(r'[ @]')).first}',
                  style: AppTheme.display(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: scheme.onSurface),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.group_outlined,
                  color: AppColors.accent,
                  value: '${_studentCount ?? '—'}',
                  label: 'Students',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.event_outlined,
                  color: AppColors.blue,
                  value: '${_eventCount ?? '—'}',
                  label: 'Events',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.quiz_outlined,
                  color: AppColors.amber,
                  value: '${_testCount ?? '—'}',
                  label: 'Tests',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tools.indexed.map((entry) {
            final (i, tool) = entry;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 80 + i * 40),
                child: SurfaceCard(
                  onTap: () => widget.onNavigate(tool.$4),
                  child: Row(
                    children: [
                      GlossyIconChip(icon: tool.$3),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tool.$1,
                                style: AppTheme.display(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurface)),
                            const SizedBox(height: 2),
                            Text(tool.$2,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45))),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: scheme.onSurface.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
