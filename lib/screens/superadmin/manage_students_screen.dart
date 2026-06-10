import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'user_edit_sheet.dart';

/// Every student account on the platform — search, edit, assign to a
/// university and verify (superadmin only).
class ManageStudentsScreen extends StatefulWidget {
  const ManageStudentsScreen({super.key});

  @override
  State<ManageStudentsScreen> createState() => _ManageStudentsScreenState();
}

class _ManageStudentsScreenState extends State<ManageStudentsScreen> {
  bool _loading = true;
  List<(String, Map<String, dynamic>)> _students = [];
  List<(String, Map<String, dynamic>)> _universities = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final db = FirebaseFirestore.instance;
    try {
      final results = await Future.wait([
        db.collection('users').where('role', isEqualTo: 'student').get(),
        db.collection('universities').get(),
      ]);
      if (mounted) {
        setState(() {
          _students = results[0].docs.map((d) => (d.id, d.data())).toList();
          _universities =
              results[1].docs.map((d) => (d.id, d.data())).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit((String, Map<String, dynamic>) student) async {
    final updated = await showUserEditSheet(
      context,
      userId: student.$1,
      data: student.$2,
      universities: _universities,
      showStudentId: true,
    );
    if (updated != null) {
      setState(() {
        _students = _students
            .map((s) =>
                s.$1 == student.$1 ? (s.$1, {...s.$2, ...updated}) : s)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _students
        : _students.where((s) {
            final d = s.$2;
            return [
              d['name'], d['email'], d['studentId'],
              d['universityName'], d['universityId'],
            ].any((v) =>
                (v?.toString().toLowerCase() ?? '').contains(q));
          }).toList();

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHeader(
            title: 'Manage Students',
            subtitle:
                '${_students.length} student account${_students.length == 1 ? '' : 's'} platform-wide',
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search by name, email, ID or university…',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No students found',
              subtitle: 'Try a different search',
            )
          else
            ...filtered.map((entry) {
              final (_, s) = entry;
              final verified = s['verified'] == true;
              final name = (s['name'] as String?) ?? 'Unnamed Student';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  onTap: () => _edit(entry),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            AppColors.accent.withValues(alpha: 0.12),
                        backgroundImage: s['photoURL'] != null
                            ? NetworkImage(s['photoURL'] as String)
                            : null,
                        child: s['photoURL'] == null
                            ? Text(name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13))
                            : null,
                      ),
                      const SizedBox(width: 12),
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
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700)),
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
                                s['email'] ?? '',
                                s['universityName'] ??
                                    s['universityId'] ??
                                    'No university',
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
