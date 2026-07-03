import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'student_view_screen.dart';

/// Students who applied to an event in-app (events posted without an
/// external link). Backed by the `eventApplications` collection.
class EventApplicantsScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  const EventApplicantsScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  Future<void> _emailAll(
      BuildContext context, List<Map<String, dynamic>> applicants) async {
    final emails = applicants
        .map((a) => (a['userEmail'] as String?) ?? '')
        .where((e) => e.isNotEmpty)
        .toSet()
        .join(',');
    if (emails.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: '',
      query: 'bcc=$emails&subject=${Uri.encodeComponent(eventTitle)}',
    );
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      showAppSnack(context, 'No email app available.', error: true);
    }
  }

  Future<void> _openProfile(BuildContext context, String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StudentViewScreen(studentId: userId, data: doc.data() ?? {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Applicants')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          // Equality-only query — no composite index needed; sorted below.
          stream: FirebaseFirestore.instance
              .collection('eventApplications')
              .where('eventId', isEqualTo: eventId)
              .limit(500)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Applicants unavailable',
                subtitle: 'Check your connection and try again',
              );
            }
            if (!snap.hasData) return const CenteredLoader();

            final apps = snap.data!.docs.map((d) => d.data()).toList()
              ..sort((a, b) =>
                  (toDate(b['appliedAt'])?.millisecondsSinceEpoch ?? 0)
                      .compareTo(
                          toDate(a['appliedAt'])?.millisecondsSinceEpoch ??
                              0));

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PageHeader(
                  title: eventTitle,
                  subtitle:
                      '${apps.length} ${apps.length == 1 ? 'student has' : 'students have'} applied in-app',
                  trailing: apps.isEmpty
                      ? null
                      : OutlinedButton.icon(
                          onPressed: () => _emailAll(context, apps),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12)),
                          icon: const Icon(Icons.mail_outline_rounded,
                              size: 14),
                          label: const Text('Email',
                              style: TextStyle(fontSize: 12)),
                        ),
                ),
                const SizedBox(height: 16),
                if (apps.isEmpty)
                  const EmptyState(
                    icon: Icons.how_to_reg_outlined,
                    title: 'No applications yet',
                    subtitle:
                        'Students who tap APPLY on this event appear here',
                  )
                else
                  ...apps.map((a) {
                    final name = (a['userName'] as String?) ?? 'Student';
                    final email = (a['userEmail'] as String?) ?? '';
                    final branch = (a['branch'] as String?) ?? '';
                    final gpa = (a['gpa'] as num?)?.toDouble();
                    final at = toDate(a['appliedAt']);
                    final userId = (a['userId'] as String?) ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SurfaceCard(
                        padding: const EdgeInsets.all(12),
                        onTap: userId.isEmpty
                            ? null
                            : () => _openProfile(context, userId),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  AppColors.accent.withValues(alpha: 0.13),
                              child: Text(
                                name.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.accent),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700)),
                                  if (email.isNotEmpty)
                                    Text(email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: scheme.onSurface
                                                .withValues(alpha: 0.45))),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (branch.isNotEmpty)
                                        Pill(
                                            label: branch,
                                            color: AppColors.blue),
                                      if (gpa != null)
                                        Pill(
                                            label: 'CGPA $gpa',
                                            color: AppColors.accent),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(timeAgo(at),
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.4))),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
