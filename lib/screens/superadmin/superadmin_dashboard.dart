import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../widgets/common.dart';

class SuperadminDashboard extends StatefulWidget {
  final void Function(String id) onNavigate;
  const SuperadminDashboard({super.key, required this.onNavigate});

  @override
  State<SuperadminDashboard> createState() => _SuperadminDashboardState();
}

class _SuperadminDashboardState extends State<SuperadminDashboard> {
  int? _universities;
  int? _admins;
  int? _students;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db.collection('universities').count().get(),
        db
            .collection('users')
            .where('role', isEqualTo: 'university_admin')
            .count()
            .get(),
        db
            .collection('users')
            .where('role', isEqualTo: 'student')
            .count()
            .get(),
      ]);
      if (mounted) {
        setState(() {
          _universities = results[0].count;
          _admins = results[1].count;
          _students = results[2].count;
        });
      }
    } catch (_) {
      // best effort
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final tools = [
      (
        'Universities',
        'Register and verify partner universities',
        Icons.account_balance_outlined,
        'universities'
      ),
      (
        'Manage Students',
        'View, edit and verify every student account',
        Icons.group_outlined,
        'manage-students'
      ),
      (
        'Create Uni Admin',
        'Add a new university administrator',
        Icons.person_add_outlined,
        'create-uniadmin'
      ),
      (
        'Manage Uni Admins',
        'Review and edit administrator accounts',
        Icons.manage_accounts_outlined,
        'manage-uniadmins'
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
                Text('SUPER ADMIN',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                        color: AppColors.accent)),
                const SizedBox(height: 5),
                Text('Platform Overview',
                    style: AppTheme.display(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: scheme.onSurface)),
                const SizedBox(height: 4),
                Text('System-wide overview of the UniShip platform',
                    style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.account_balance_outlined,
                  color: AppColors.accent,
                  value: '${_universities ?? '—'}',
                  label: 'Universities',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.manage_accounts_outlined,
                  color: AppColors.blue,
                  value: '${_admins ?? '—'}',
                  label: 'Uni Admins',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.group_outlined,
                  color: AppColors.success,
                  value: '${_students ?? '—'}',
                  label: 'Students',
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
