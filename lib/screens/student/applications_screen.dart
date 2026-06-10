import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _applications = [];

  static Color statusColor(String status) => switch (status) {
        'selected' => AppColors.success,
        'rejected' => AppColors.danger,
        'shortlisted' => AppColors.blue,
        _ => AppColors.amber,
      };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('applications')
          .where('userId', isEqualTo: uid)
          .get();
      final apps = snap.docs.map((d) => d.data()).toList()
        ..sort((a, b) {
          final da = toDate(a['appliedAt'])?.millisecondsSinceEpoch ?? 0;
          final db = toDate(b['appliedAt'])?.millisecondsSinceEpoch ?? 0;
          return db.compareTo(da);
        });
      if (mounted) {
        setState(() {
          _applications = apps;
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
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const PageHeader(
            title: 'My Applications',
            subtitle: 'Track the status of your professional opportunities.',
          ),
          const SizedBox(height: 16),
          if (_applications.isEmpty)
            const EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No applications found.',
              subtitle: 'Apply to internships to see them here.',
            )
          else
            ..._applications.map((app) {
              final status = (app['status'] as String?) ?? 'pending';
              final color = statusColor(status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.business_rounded,
                                    size: 12,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.35)),
                                const SizedBox(width: 6),
                                Text(
                                  (app['companyName'] as String?) ?? '—',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              (app['internshipRole'] as String?) ?? 'Role',
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.4)),
                                const SizedBox(width: 5),
                                Text(
                                  'Applied ${formatDate(toDate(app['appliedAt']))}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Pill(label: status, color: color),
                    ],
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
