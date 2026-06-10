import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'user_edit_sheet.dart';

/// All university_admin accounts with edit (name / phone / university /
/// verified) — superadmin only.
class ManageUniadminsScreen extends StatefulWidget {
  const ManageUniadminsScreen({super.key});

  @override
  State<ManageUniadminsScreen> createState() => _ManageUniadminsScreenState();
}

class _ManageUniadminsScreenState extends State<ManageUniadminsScreen> {
  bool _loading = true;
  List<(String, Map<String, dynamic>)> _admins = [];
  List<(String, Map<String, dynamic>)> _universities = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db
            .collection('users')
            .where('role', isEqualTo: 'university_admin')
            .get(),
        db.collection('universities').get(),
      ]);
      if (mounted) {
        setState(() {
          _admins = results[0].docs.map((d) => (d.id, d.data())).toList();
          _universities =
              results[1].docs.map((d) => (d.id, d.data())).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit((String, Map<String, dynamic>) admin) async {
    final updated = await showUserEditSheet(
      context,
      userId: admin.$1,
      data: admin.$2,
      universities: _universities,
      showStudentId: false,
    );
    if (updated != null) {
      setState(() {
        _admins = _admins
            .map((a) => a.$1 == admin.$1 ? (a.$1, {...a.$2, ...updated}) : a)
            .toList();
      });
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
          PageHeader(
            title: 'Manage Uni Admins',
            subtitle:
                '${_admins.length} administrator account${_admins.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 16),
          if (_admins.isEmpty)
            const EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'No university admins yet',
              subtitle: 'Create one from the Create Admin page',
            )
          else
            ..._admins.map((entry) {
              final (_, a) = entry;
              final verified = a['verified'] == true;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  onTap: () => _edit(entry),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.admin_panel_settings_outlined,
                            size: 18, color: AppColors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    (a['name'] as String?) ?? 'Unnamed',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Pill(
                                  label:
                                      verified ? 'Verified' : 'Unverified',
                                  color: verified
                                      ? AppColors.success
                                      : AppColors.amber,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              [
                                a['email'] ?? '',
                                a['universityName'] ??
                                    a['universityId'] ??
                                    '',
                              ]
                                  .where((v) => v.toString().isNotEmpty)
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.45)),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit_outlined,
                          size: 16,
                          color: scheme.onSurface.withValues(alpha: 0.35)),
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
