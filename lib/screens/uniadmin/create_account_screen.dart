import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/student_filters.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';

/// Register a student account for the admin's university. Uses a secondary
/// Firebase app so the admin stays signed in (improves on the web flow).
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _studentId = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  String? _branch;

  bool _submitting = false;
  String _success = '';

  @override
  void dispose() {
    for (final c in [_name, _studentId, _email, _password, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthService>();
    if (auth.universityId == null) {
      showAppSnack(context, 'Profile Error: University ID not found.',
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
        'role': 'student',
        'universityId': auth.universityId,
        'studentId': _studentId.text.trim(),
        'universityName': auth.universityName ?? '',
        'verified': false,
        'branch': _branch,
        'phone': _phone.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': auth.user?.uid,
      });
      if (mounted) {
        setState(() => _success = 'Account created for ${_email.text.trim()}');
        _formKey.currentState?.reset();
        for (final c in [_name, _studentId, _email, _password, _phone]) {
          c.clear();
        }
        setState(() => _branch = null);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showAppSnack(
          context,
          switch (e.code) {
            'email-already-in-use' => 'This email is already registered.',
            'weak-password' => 'Password should be at least 6 characters.',
            'invalid-email' => 'Invalid email address.',
            _ => 'Failed to create account (${e.code}).',
          },
          error: true,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to create account.', error: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageHeader(
          title: 'Register Student',
          subtitle: 'University ID: ${auth.universityId ?? 'Loading…'}',
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
                const FieldLabel('Full Name *'),
                TextFormField(
                  controller: _name,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Student ID *'),
                TextFormField(
                  controller: _studentId,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Email Address *'),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Temporary Password *'),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Min 6 characters'
                      : null,
                ),
                const SizedBox(height: 14),
                const FieldLabel('Branch / Department'),
                DropdownButtonFormField<String?>(
                  initialValue: _branch,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child:
                          Text('Not set', style: TextStyle(fontSize: 13.5)),
                    ),
                    for (final b in kBranches)
                      DropdownMenuItem<String?>(
                        value: b,
                        child:
                            Text(b, style: const TextStyle(fontSize: 13.5)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _branch = v),
                ),
                const SizedBox(height: 14),
                const FieldLabel('Phone Number'),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: 'Complete Registration',
                  icon: Icons.person_add_alt_1_rounded,
                  loading: _submitting,
                  onPressed:
                      (_submitting || auth.universityId == null) ? null : _submit,
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
