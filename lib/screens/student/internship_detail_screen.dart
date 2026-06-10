import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

class InternshipDetailScreen extends StatefulWidget {
  final String internshipId;
  const InternshipDetailScreen({super.key, required this.internshipId});

  @override
  State<InternshipDetailScreen> createState() => _InternshipDetailScreenState();
}

class _InternshipDetailScreenState extends State<InternshipDetailScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _applying = false;
  bool _hasApplied = false;
  Map<String, dynamic>? _internship;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final uid = context.read<AuthService>().user?.uid;
    try {
      final doc =
          await _db.collection('internships').doc(widget.internshipId).get();
      if (doc.exists) {
        _internship = doc.data();
        if (uid != null) {
          final appSnap = await _db
              .collection('applications')
              .where('internshipId', isEqualTo: widget.internshipId)
              .where('userId', isEqualTo: uid)
              .get();
          _hasApplied = appSnap.docs.isNotEmpty;
        }
      }
    } catch (_) {
      // handled by empty state below
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _apply() async {
    final auth = context.read<AuthService>();
    final user = auth.user;
    final internship = _internship;
    if (user == null || internship == null) return;
    setState(() => _applying = true);
    try {
      await _db.collection('applications').add({
        'internshipId': widget.internshipId,
        'internshipRole': internship['role'],
        'companyName': internship['companyName'],
        'userId': user.uid,
        'userEmail': user.email,
        'status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _hasApplied = true);
        showAppSnack(context, 'Application submitted successfully!');
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to submit application.', error: true);
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Internship')),
      body: _loading
          ? const CenteredLoader()
          : _internship == null
              ? const Center(child: Text('Internship not found.'))
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      SurfaceCard(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ((_internship!['companyName'] as String?) ?? '')
                                    .toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (_internship!['role'] as String?) ?? 'Internship',
                              style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (_internship!['location'] as String?) ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.5)),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoTile(
                                    label: 'Stipend',
                                    value: (_internship!['stipend']
                                            as String?) ??
                                        '—',
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _InfoTile(
                                    label: 'Duration',
                                    value: (_internship!['duration']
                                            as String?) ??
                                        '—',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _InfoTile(
                              label: 'Application Deadline',
                              value: formatDate(toDate(_internship!['deadline'])),
                              accent: true,
                            ),
                            const SizedBox(height: 20),
                            const FieldLabel('About the Role'),
                            Text(
                              (_internship!['description'] as String?) ?? '',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.55,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.75)),
                            ),
                            if (_internship!['requirements'] is List &&
                                (_internship!['requirements'] as List)
                                    .isNotEmpty) ...[
                              const SizedBox(height: 18),
                              const FieldLabel('Requirements'),
                              ...(_internship!['requirements'] as List).map(
                                (req) => Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: Icon(Icons.circle,
                                            size: 5, color: AppColors.accent),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          req.toString(),
                                          style: TextStyle(
                                              fontSize: 13,
                                              height: 1.4,
                                              color: scheme.onSurface
                                                  .withValues(alpha: 0.75)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_hasApplied)
                        SurfaceCard(
                          borderColor: AppColors.success,
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: AppColors.success, size: 26),
                              const SizedBox(height: 8),
                              const Text('Application Submitted',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              const SizedBox(height: 3),
                              Text(
                                'Track its status from the Applications page.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: _applying ? null : _apply,
                          child: Text(_applying ? 'PROCESSING…' : 'APPLY NOW'),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _InfoTile({required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: accent ? AppColors.accent : null,
            ),
          ),
        ],
      ),
    );
  }
}
