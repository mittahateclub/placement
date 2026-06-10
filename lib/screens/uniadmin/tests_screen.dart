import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

/// Manage the university's tests: approve/unapprove for students, delete,
/// see schedule and question counts. (AI test creation from PDFs stays on
/// the web portal; this manages what exists.)
class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  List<(String, Map<String, dynamic>)> _tests = [];

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
      final snap = await _db
          .collection('tests')
          .where('universityId', isEqualTo: universityId)
          .get();
      final list = snap.docs.map((d) => (d.id, d.data())).toList()
        ..sort((a, b) =>
            (toDate(b.$2['createdAt'])?.millisecondsSinceEpoch ?? 0).compareTo(
                toDate(a.$2['createdAt'])?.millisecondsSinceEpoch ?? 0));
      if (mounted) {
        setState(() {
          _tests = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleApproval(String id, bool current) async {
    try {
      await _db.collection('tests').doc(id).update({'approved': !current});
      setState(() {
        _tests = _tests
            .map((t) =>
                t.$1 == id ? (t.$1, {...t.$2, 'approved': !current}) : t)
            .toList();
      });
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to update approval.', error: true);
      }
    }
  }

  Future<void> _delete(String id, String title) async {
    final confirmed = await confirmDialog(context,
        title: 'Delete test?',
        message: '"$title" will be permanently removed.');
    if (!confirmed) return;
    try {
      await _db.collection('tests').doc(id).delete();
      setState(() => _tests.removeWhere((t) => t.$1 == id));
    } catch (_) {
      if (mounted) showAppSnack(context, 'Failed to delete test.', error: true);
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
            title: 'Manage Tests',
            subtitle:
                'Approve tests for students and manage existing assessments. Create new AI tests from the web portal.',
          ),
          const SizedBox(height: 16),
          if (_tests.isEmpty)
            const EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No tests yet',
              subtitle:
                  'Upload a PDF on the web portal to generate a test with AI',
            )
          else
            ..._tests.map((entry) {
              final (id, t) = entry;
              final approved = t['approved'] == true;
              final title = (t['title'] as String?) ?? 'Untitled Test';
              final questions = (t['totalQuestions'] as num?)?.toInt();
              final start = toDate(t['examStart']);
              final end = toDate(t['examEnd']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Pill(
                            label: approved ? 'Approved' : 'Not Approved',
                            color: approved
                                ? AppColors.success
                                : AppColors.amber,
                            icon: approved
                                ? Icons.check_circle_outline_rounded
                                : Icons.cancel_outlined,
                          ),
                        ],
                      ),
                      if ((t['description'] ?? '') != '') ...[
                        const SizedBox(height: 5),
                        Text(t['description'].toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          if (questions != null)
                            Text('$questions questions',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45))),
                          if ((t['duration'] ?? '') != '')
                            Text('${t['duration']} min',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45))),
                          if (start != null)
                            Text('Starts ${formatDateTime(start)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45))),
                          if (end != null)
                            Text('Ends ${formatDateTime(end)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => _toggleApproval(id, approved),
                            style: TextButton.styleFrom(
                              foregroundColor: approved
                                  ? AppColors.amber
                                  : AppColors.success,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                            icon: Icon(
                                approved
                                    ? Icons.unpublished_outlined
                                    : Icons.verified_outlined,
                                size: 15),
                            label: Text(approved ? 'Unapprove' : 'Approve'),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _delete(id, title),
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 18,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.4)),
                          ),
                        ],
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
