import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

/// Shared superadmin edit sheet for students & uni admins: name, phone,
/// (student ID,) university assignment and verified flag.
/// Returns the updated field map on save, or null if dismissed.
Future<Map<String, dynamic>?> showUserEditSheet(
  BuildContext context, {
  required String userId,
  required Map<String, dynamic> data,
  required List<(String, Map<String, dynamic>)> universities,
  required bool showStudentId,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _UserEditSheet(
      userId: userId,
      data: data,
      universities: universities,
      showStudentId: showStudentId,
    ),
  );
}

class _UserEditSheet extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> data;
  final List<(String, Map<String, dynamic>)> universities;
  final bool showStudentId;

  const _UserEditSheet({
    required this.userId,
    required this.data,
    required this.universities,
    required this.showStudentId,
  });

  @override
  State<_UserEditSheet> createState() => _UserEditSheetState();
}

class _UserEditSheetState extends State<_UserEditSheet> {
  late final TextEditingController _name =
      TextEditingController(text: (widget.data['name'] as String?) ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: (widget.data['phone'] as String?) ?? '');
  late final TextEditingController _studentId = TextEditingController(
      text: (widget.data['studentId'] as String?) ?? '');

  String? _universityCode;
  late bool _verified = widget.data['verified'] == true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final current = widget.data['universityId'] as String?;
    // Only preselect codes that exist in the dropdown.
    if (widget.universities.any((u) => u.$2['code'] == current)) {
      _universityCode = current;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _studentId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final selected = widget.universities
        .where((u) => u.$2['code'] == _universityCode)
        .map((u) => u.$2)
        .firstOrNull;
    if (selected == null) {
      showAppSnack(context, 'Please select a valid university.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final updates = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (widget.showStudentId) 'studentId': _studentId.text.trim(),
        'universityId': selected['code'],
        'universityName': selected['name'],
        'verified': _verified,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update(updates);
      if (mounted) {
        Navigator.pop(context, {...updates}..remove('updatedAt'));
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to save changes.', error: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Edit Account',
                    style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              (widget.data['email'] as String?) ?? '',
              style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            const FieldLabel('Full Name'),
            TextField(controller: _name),
            const SizedBox(height: 12),
            if (widget.showStudentId) ...[
              const FieldLabel('Student ID'),
              TextField(controller: _studentId),
              const SizedBox(height: 12),
            ],
            const FieldLabel('Phone'),
            TextField(controller: _phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            const FieldLabel('University'),
            DropdownButtonFormField<String>(
              initialValue: _universityCode,
              isExpanded: true,
              hint: const Text('Select a university',
                  style: TextStyle(fontSize: 13.5)),
              items: widget.universities
                  .map((u) => DropdownMenuItem(
                        value: u.$2['code'] as String?,
                        child: Text(
                          '${u.$2['name']} (${u.$2['code']})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _universityCode = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verified',
                  style:
                      TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              value: _verified,
              onChanged: (v) => setState(() => _verified = v),
            ),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Save Changes',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
