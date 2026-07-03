import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

/// Create a university_admin account bound to a verified university.
class CreateUniadminScreen extends StatefulWidget {
  const CreateUniadminScreen({super.key});

  @override
  State<CreateUniadminScreen> createState() => _CreateUniadminScreenState();
}

class _CreateUniadminScreenState extends State<CreateUniadminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();

  bool _loadingUnis = true;
  bool _submitting = false;
  String _success = '';
  List<(String, Map<String, dynamic>)> _universities = [];
  String? _selectedUniId;

  @override
  void initState() {
    super.initState();
    _fetchUniversities();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchUniversities() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('universities').get();
      if (mounted) {
        setState(() {
          _universities = snap.docs.map((d) => (d.id, d.data())).toList();
          _loadingUnis = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingUnis = false);
    }
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    final selected = _universities
        .where((u) => u.$1 == _selectedUniId)
        .map((u) => u.$2)
        .firstOrNull;
    if (selected == null) {
      showAppSnack(context, 'Please select a university.', error: true);
      return;
    }
    if (selected['verified'] != true) {
      showAppSnack(context,
          'Selected university is not verified. Verify it first from the Universities page.',
          error: true);
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _success = '';
    });
    try {
      final uid = await auth.createManagedAccount(
        email: _email.text.trim(),
        password: _password.text,
      );
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'role': 'university_admin',
        'universityName': selected['name'],
        'universityId': selected['code'],
        'phone': _phone.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': auth.user?.uid,
        'verified': true,
      });
      if (mounted) {
        setState(() => _success =
            'Admin account created for ${_email.text.trim()} → ${selected['name']}');
        _formKey.currentState?.reset();
        for (final c in [_name, _email, _password, _phone]) {
          c.clear();
        }
        setState(() => _selectedUniId = null);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          switch (e.code) {
            'email-already-in-use' => 'This email is already registered.',
            'weak-password' => 'Password should be at least 6 characters.',
            _ => 'Failed to create account (${e.code}).',
          },
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to create account. Please try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingUnis) return const CenteredLoader();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Create University Admin',
          subtitle: 'Add a new university administrator account',
        ),
        const SizedBox(height: 16),
        if (_success.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Text(_success,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
          ),
          const SizedBox(height: 12),
        ],
        SurfaceCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FieldLabel('University *'),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUniId,
                  isExpanded: true,
                  hint: const Text('Select a university',
                      style: TextStyle(fontSize: 13.5)),
                  items: _universities
                      .map((u) => DropdownMenuItem(
                            value: u.$1,
                            child: Row(
                              children: [
                                Icon(
                                  u.$2['verified'] == true
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  size: 14,
                                  color: u.$2['verified'] == true
                                      ? AppColors.success
                                      : AppColors.amber,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${u.$2['name']} (${u.$2['code']})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(fontSize: 13.5),
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedUniId = v),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Full Name *'),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                      hintText: "Enter admin's full name"),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Email Address *'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      hintText: 'admin@university.edu'),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Password *'),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration:
                      const InputDecoration(hintText: 'Min 6 characters'),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Min 6 characters'
                      : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Phone Number'),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Create Admin',
                  icon: Icons.person_add_alt_1_rounded,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
