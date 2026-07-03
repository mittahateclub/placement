import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

/// University admin account details (name & phone editable).
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _data = doc.data() ?? {};
      _name.text = (_data['name'] as String?) ?? '';
      _phone.text = (_data['phone'] as String?) ?? '';
    } catch (_) {
      // show what we have
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showAppSnack(context, 'Profile updated!');
        await context.read<AuthService>().refreshProfile();
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to update profile.', error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final auth = context.watch<AuthService>();
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Admin Profile',
          subtitle: 'Your account and university details',
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Account'),
              _row(context, Icons.mail_outline_rounded, 'Email',
                  auth.user?.email ?? '—'),
              _row(context, Icons.account_balance_outlined, 'University',
                  auth.universityName ?? '—'),
              _row(context, Icons.tag_rounded, 'University ID',
                  auth.universityId ?? '—'),
              _row(
                  context,
                  Icons.verified_outlined,
                  'Status',
                  _data['verified'] == true ? 'Verified' : 'Unverified'),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 14),
              const FieldLabel('Full Name'),
              TextField(controller: _name),
              const SizedBox(height: 14),
              const FieldLabel('Phone'),
              TextField(
                  controller: _phone, keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Save Changes',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Row(
            children: [
              const Icon(Icons.shield_outlined,
                  size: 18, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Live exam proctoring and AI test creation are available on the UniShip web portal.',
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: scheme.onSurface.withValues(alpha: 0.55)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(icon, size: 15, color: scheme.onSurface.withValues(alpha: 0.4)),
          const SizedBox(width: 9),
          SizedBox(
            width: 96,
            child: Text(label.toUpperCase(),
                style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: scheme.onSurface.withValues(alpha: 0.4))),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
