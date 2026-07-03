import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../widgets/common.dart';

/// Read-only full profile of one student (admin view).
class StudentViewScreen extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic> data;

  const StudentViewScreen(
      {super.key, required this.studentId, required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (data['name'] as String?) ?? 'Unnamed Student';

    return Scaffold(
      appBar: AppBar(title: const Text('Student Profile')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SurfaceCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppColors.blue.withValues(alpha: 0.12),
                    backgroundImage: data['photoURL'] != null
                        ? NetworkImage(data['photoURL'] as String)
                        : null,
                    child: data['photoURL'] == null
                        ? Text(name.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.blue))
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: AppTheme.display(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                  if ((data['title'] ?? '') != '') ...[
                    const SizedBox(height: 3),
                    Text(data['title'].toString(),
                        style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurface.withValues(alpha: 0.5))),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if ((data['rollNumber'] ?? data['studentId'] ?? '') !=
                          '')
                        Pill(
                            label:
                                '${data['rollNumber'] ?? data['studentId']}',
                            color: AppColors.accent),
                      if (data['verified'] == true)
                        const Pill(label: 'Verified', color: AppColors.success)
                      else
                        const Pill(label: 'Unverified', color: AppColors.amber),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _kvCard(context, 'Contact', {
              'Email': data['email'],
              'Phone': data['phone'],
              'LinkedIn': data['linkedinUrl'],
              'GitHub': data['githubUrl'],
            }),
            if ((data['bio'] ?? '') != '')
              _textCard(context, 'Bio', data['bio'].toString()),
            if ((data['technicalSkills'] ?? '') != '')
              _chipsCard(context, 'Technical Skills',
                  data['technicalSkills'].toString()),
            if ((data['relevantCoursework'] ?? '') != '')
              _textCard(context, 'Relevant Coursework',
                  data['relevantCoursework'].toString()),
            _entriesCard(context, 'Education', data['educationEntries'],
                (e) => [
                      e['institution'],
                      e['degree'],
                      if ((e['cgpa'] ?? '') != '') 'CGPA: ${e['cgpa']}',
                      _range(e),
                    ]),
            _entriesCard(context, 'Experience', data['experienceEntries'],
                (e) => [
                      '${e['role'] ?? ''} @ ${e['company'] ?? ''}',
                      _range(e),
                      e['description'],
                    ]),
            _entriesCard(context, 'Projects', data['projectEntries'],
                (e) => [
                      e['title'],
                      e['techStack'],
                      _range(e),
                      e['description'],
                    ]),
            _entriesCard(
                context,
                'Achievements',
                data['achievementEntries'],
                (e) => [e['title'], e['issuer'], _range(e)]),
            _entriesCard(context, 'Positions', data['positionEntries'],
                (e) => [e['title'], e['organization'], _range(e)]),
            _entriesCard(
                context,
                'Extracurriculars',
                data['extracurricularEntries'],
                (e) => [e['activity'], e['role'], _range(e)]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  static String _range(Map e) {
    final from = e['fromDate']?.toString() ?? '';
    final to = e['toDate']?.toString() ?? '';
    if (from.isNotEmpty && to.isNotEmpty) return '$from – $to';
    if (from.isNotEmpty) return '$from – Present';
    return to;
  }

  Widget _kvCard(
      BuildContext context, String title, Map<String, dynamic> pairs) {
    final scheme = Theme.of(context).colorScheme;
    final entries = pairs.entries
        .where((e) => (e.value?.toString() ?? '').isNotEmpty)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title, padding: EdgeInsets.zero),
            const SizedBox(height: 10),
            ...entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(e.key.toUpperCase(),
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.4))),
                      ),
                      Expanded(
                        child: Text(e.value.toString(),
                            style: const TextStyle(fontSize: 12.5)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _textCard(BuildContext context, String title, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title, padding: EdgeInsets.zero),
            const SizedBox(height: 8),
            Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: scheme.onSurface.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }

  Widget _chipsCard(BuildContext context, String title, String raw) {
    final skills = raw
        .split(RegExp(r'[,\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title, padding: EdgeInsets.zero),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: skills
                  .map((s) => Pill(label: s, color: AppColors.blue))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entriesCard(BuildContext context, String title, dynamic rawEntries,
      List<dynamic> Function(Map e) lines) {
    final scheme = Theme.of(context).colorScheme;
    final entries = (rawEntries as List? ?? []).whereType<Map>().toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title, padding: EdgeInsets.zero),
            const SizedBox(height: 10),
            ...entries.map((e) {
              final parts = lines(e)
                  .map((v) => v?.toString() ?? '')
                  .where((v) => v.isNotEmpty)
                  .toList();
              if (parts.isEmpty) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(parts.first,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    ...parts.skip(1).map((p) => Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(p,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.6))),
                        )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
