import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'student_view_screen.dart';

/// Centralized student repository for the admin's university: full-profile
/// search, CGPA filter, stats, view & delete.
class StudentDatabaseScreen extends StatefulWidget {
  const StudentDatabaseScreen({super.key});

  @override
  State<StudentDatabaseScreen> createState() => _StudentDatabaseScreenState();
}

class _StudentDatabaseScreenState extends State<StudentDatabaseScreen> {
  bool _loading = true;
  List<(String, Map<String, dynamic>)> _students = [];
  String _query = '';
  double? _minCgpa;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final universityId = context.read<AuthService>().universityId;
    if (universityId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('universityId', isEqualTo: universityId)
          .get();
      if (mounted) {
        setState(() {
          _students = snap.docs.map((d) => (d.id, d.data())).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static double? cgpaOf(Map<String, dynamic> s) {
    for (final entry in (s['educationEntries'] as List? ?? [])) {
      if (entry is Map && entry['cgpa'] != null) {
        final num = double.tryParse(
            entry['cgpa'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        if (num != null) return num;
      }
    }
    return null;
  }

  static int internshipsOf(Map<String, dynamic> s) =>
      (s['experienceEntries'] as List? ?? [])
          .whereType<Map>()
          .where((e) =>
              (e['role']?.toString().toLowerCase() ?? '').contains('intern'))
          .length;

  static List<String> skillsOf(Map<String, dynamic> s) =>
      (s['technicalSkills']?.toString() ?? '')
          .split(RegExp(r'[,\n]+'))
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty)
          .toList();

  List<(String, Map<String, dynamic>)> get _filtered {
    final q = _query.trim().toLowerCase();
    return _students.where((entry) {
      final s = entry.$2;
      final cgpa = cgpaOf(s);
      final searchable = [
        s['name'], s['email'], s['phone'], s['studentId'], s['rollNumber'],
        s['technicalSkills'], s['title'],
        s['educationEntries'], s['experienceEntries'], s['projectEntries'],
        s['achievementEntries'], s['positionEntries'],
        s['extracurricularEntries'],
      ].map((v) => v?.toString() ?? '').join(' ').toLowerCase();
      final searchOk = q.isEmpty || searchable.contains(q);
      final cgpaOk =
          _minCgpa == null || (cgpa != null && cgpa >= _minCgpa!);
      return searchOk && cgpaOk;
    }).toList();
  }

  Future<void> _delete(String id, String name) async {
    final confirmed = await confirmDialog(context,
        title: 'Delete student?',
        message: 'Are you sure you want to delete $name? This removes their profile record.');
    if (!confirmed) return;
    setState(() => _deletingId = id);
    try {
      await FirebaseFirestore.instance.collection('users').doc(id).delete();
      setState(() => _students.removeWhere((s) => s.$1 == id));
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to delete student. Check permissions.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    final cgpas = _students.map((s) => cgpaOf(s.$2)).whereType<double>();
    final avgCgpa = cgpas.isEmpty
        ? null
        : cgpas.reduce((a, b) => a + b) / cgpas.length;
    final withInternships =
        _students.where((s) => internshipsOf(s.$2) > 0).length;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHeader(
            title: 'Student Repository',
            subtitle:
                '${_students.length} student record${_students.length == 1 ? '' : 's'}',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.groups_outlined,
                  color: AppColors.accent,
                  value: '${_students.length}',
                  label: 'Students',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.school_outlined,
                  color: AppColors.blue,
                  value: avgCgpa?.toStringAsFixed(2) ?? 'N/A',
                  label: 'Avg CGPA',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  icon: Icons.business_center_outlined,
                  color: AppColors.amber,
                  value: '$withInternships',
                  label: 'With Interns',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search name, email, ID, skills, projects…',
              prefixIcon: Icon(Icons.search_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (v) =>
                      setState(() => _minCgpa = double.tryParse(v)),
                  decoration: const InputDecoration(
                    hintText: 'Min CGPA',
                    prefixIcon: Icon(Icons.filter_alt_outlined, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_students.isEmpty)
            const EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No students found for your university.',
              subtitle: 'Register students to see them here',
            )
          else if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'No students match your filters.',
              subtitle: 'Try a different search or CGPA threshold',
            )
          else
            ...filtered.map((entry) {
              final (id, s) = entry;
              final cgpa = cgpaOf(s);
              final skills = skillsOf(s);
              final name = (s['name'] as String?) ?? 'Unnamed Student';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  padding: const EdgeInsets.all(12),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentViewScreen(studentId: id, data: s),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 19,
                        backgroundColor:
                            AppColors.blue.withValues(alpha: 0.12),
                        backgroundImage: s['photoURL'] != null
                            ? NetworkImage(s['photoURL'] as String)
                            : null,
                        child: s['photoURL'] == null
                            ? Text(
                                name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.blue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                s['rollNumber'] ?? s['studentId'] ?? '',
                                s['email'] ?? '',
                              ]
                                  .where(
                                      (v) => v.toString().isNotEmpty)
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.45)),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (cgpa != null)
                                  Text('CGPA ${cgpa.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.blue)),
                                Text('${skills.length} skills',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.4))),
                                Text(
                                    '${internshipsOf(s)} internship roles',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.4))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_deletingId == id)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _delete(id, name),
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 18,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4)),
                        ),
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
