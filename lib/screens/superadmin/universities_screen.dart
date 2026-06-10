import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

/// Register, verify/revoke and delete universities; shows admin & student
/// counts per university (matched by university code, like the website).
class UniversitiesScreen extends StatefulWidget {
  const UniversitiesScreen({super.key});

  @override
  State<UniversitiesScreen> createState() => _UniversitiesScreenState();
}

class _UniversitiesScreenState extends State<UniversitiesScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  List<(String, Map<String, dynamic>)> _universities = [];
  Map<String, int> _adminCounts = {};
  Map<String, int> _studentCounts = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final results = await Future.wait([
        _db.collection('universities').get(),
        _db.collection('users').get(),
      ]);
      final unis = results[0].docs.map((d) => (d.id, d.data())).toList();
      final adminCounts = <String, int>{};
      final studentCounts = <String, int>{};
      for (final d in results[1].docs) {
        final data = d.data();
        final uid = data['universityId'] as String?;
        if (uid == null) continue;
        if (data['role'] == 'university_admin') {
          adminCounts[uid] = (adminCounts[uid] ?? 0) + 1;
        }
        if (data['role'] == 'student') {
          studentCounts[uid] = (studentCounts[uid] ?? 0) + 1;
        }
      }
      if (mounted) {
        setState(() {
          _universities = unis;
          _adminCounts = adminCounts;
          _studentCounts = studentCounts;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateSheet() async {
    final name = TextEditingController();
    final code = TextEditingController();
    final domain = TextEditingController();
    var creating = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Register University',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              const FieldLabel('University Name *'),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                    hintText: 'e.g. Harvard University'),
              ),
              const SizedBox(height: 12),
              const FieldLabel('University Code *'),
              TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                decoration:
                    const InputDecoration(hintText: 'e.g. HARV-001'),
              ),
              const SizedBox(height: 12),
              const FieldLabel('Domain'),
              TextField(
                controller: domain,
                decoration:
                    const InputDecoration(hintText: 'e.g. harvard.edu'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: creating
                    ? null
                    : () async {
                        final uniName = name.text.trim();
                        final uniCode =
                            code.text.trim().toUpperCase();
                        if (uniName.isEmpty || uniCode.isEmpty) {
                          showAppSnack(sheetContext,
                              'Name and code are required.',
                              error: true);
                          return;
                        }
                        if (_universities.any((u) =>
                            (u.$2['code'] as String? ?? '')
                                .toLowerCase() ==
                            uniCode.toLowerCase())) {
                          showAppSnack(sheetContext,
                              'A university with this code already exists.',
                              error: true);
                          return;
                        }
                        setSheetState(() => creating = true);
                        try {
                          await _db.collection('universities').add({
                            'name': uniName,
                            'code': uniCode,
                            'domain': domain.text.trim(),
                            'verified': false,
                            'createdAt': FieldValue.serverTimestamp(),
                            'createdBy':
                                context.read<AuthService>().user?.uid,
                          });
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
                          _fetch();
                        } catch (_) {
                          if (sheetContext.mounted) {
                            showAppSnack(sheetContext,
                                'Failed to create university.',
                                error: true);
                          }
                          setSheetState(() => creating = false);
                        }
                      },
                child: Text(
                    creating ? 'REGISTERING…' : 'REGISTER UNIVERSITY'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleVerification(String id, bool verified) async {
    try {
      await _db
          .collection('universities')
          .doc(id)
          .update({'verified': !verified});
      setState(() {
        _universities = _universities
            .map((u) =>
                u.$1 == id ? (u.$1, {...u.$2, 'verified': !verified}) : u)
            .toList();
      });
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to update verification.', error: true);
      }
    }
  }

  Future<void> _delete(String id, String name) async {
    final confirmed = await confirmDialog(context,
        title: 'Delete university?',
        message:
            'Delete "$name"? This will not remove associated admins or students.');
    if (!confirmed) return;
    try {
      await _db.collection('universities').doc(id).delete();
      setState(() => _universities.removeWhere((u) => u.$1 == id));
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to delete university.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;

    final filtered = _query.trim().isEmpty
        ? _universities
        : _universities.where((u) {
            final q = _query.toLowerCase();
            return (u.$2['name']?.toString().toLowerCase() ?? '').contains(q) ||
                (u.$2['code']?.toString().toLowerCase() ?? '').contains(q) ||
                (u.$2['domain']?.toString().toLowerCase() ?? '').contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add University'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PageHeader(
              title: 'Manage Universities',
              subtitle:
                  '${_universities.length} registered universit${_universities.length == 1 ? 'y' : 'ies'}',
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search universities…',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              EmptyState(
                icon: Icons.account_balance_outlined,
                title: _query.isEmpty
                    ? 'No universities registered yet.'
                    : 'No universities match your search.',
                subtitle: _query.isEmpty
                    ? 'Tap "Add University" to register one'
                    : 'Try a different query',
              )
            else
              ...filtered.map((entry) {
                final (id, u) = entry;
                final verified = u['verified'] == true;
                final code = (u['code'] as String?) ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SurfaceCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: verified
                                ? AppColors.success.withValues(alpha: 0.12)
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_balance_outlined,
                              size: 18,
                              color: verified
                                  ? AppColors.success
                                  : scheme.onSurface
                                      .withValues(alpha: 0.35)),
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
                                      (u['name'] as String?) ?? 'Unnamed',
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
                                        verified ? 'Verified' : 'Pending',
                                    color: verified
                                        ? AppColors.success
                                        : AppColors.amber,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  code,
                                  if ((u['domain'] ?? '') != '')
                                    u['domain'].toString(),
                                  '${_adminCounts[code] ?? 0} admins',
                                  '${_studentCounts[code] ?? 0} students',
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _toggleVerification(id, verified),
                          style: TextButton.styleFrom(
                            foregroundColor: verified
                                ? AppColors.amber
                                : AppColors.success,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                          child: Text(verified ? 'Revoke' : 'Verify'),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _delete(id, (u['name'] as String?) ?? ''),
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
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
