import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_config.dart';
import '../../models/resume_data.dart';
import '../../services/auth_service.dart';
import '../../services/groq_service.dart';
import '../../widgets/app_drawer.dart' show showGroqKeySheet;
import '../../widgets/ats_panel.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import '../../widgets/resume_preview.dart';

/// AI Resume Builder — pulls the student profile, tailors it against a job
/// description with Groq, shows ATS score + live preview, saves to Firestore.
class ResumeBuilderScreen extends StatefulWidget {
  final void Function(String id) onNavigate;
  const ResumeBuilderScreen({super.key, required this.onNavigate});

  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _company = TextEditingController();
  final _jobDescription = TextEditingController();

  bool _loading = true;
  bool _generating = false;
  bool _saving = false;
  Map<String, dynamic>? _profile;
  ResumeData _resume = ResumeData();
  List<String> _keywords = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _company.dispose();
    _jobDescription.dispose();
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
      if (doc.exists) {
        _profile = doc.data();
        _resume = ResumeData.fromProfile(_profile!);
      }
    } catch (_) {
      // fall through to empty builder
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generate() async {
    if (_company.text.trim().isEmpty || _jobDescription.text.trim().isEmpty) {
      showAppSnack(context,
          'Please enter both the company name and job description.',
          error: true);
      return;
    }
    if (_profile == null) {
      showAppSnack(context,
          'No profile data found. Please fill out your profile first.',
          error: true);
      return;
    }
    if (!AppConfig.hasGroqKey) {
      await showGroqKeySheet(context);
      if (!AppConfig.hasGroqKey) return;
    }
    setState(() => _generating = true);
    try {
      final generated = await GroqService.generateTailoredResume(
        profileData: _profile!,
        companyName: _company.text,
        jobDescription: _jobDescription.text,
      );
      if (mounted) {
        setState(() {
          _resume.mergeGenerated(generated);
          _keywords = _resume.keywords;
        });
        showAppSnack(context, 'Resume tailored for ${_company.text.trim()}!');
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(
            context, e.toString().replaceFirst('Exception: ', ''),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _save() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      _resume.targetCompany = _company.text.trim();
      _resume.keywords = _keywords;
      await FirebaseFirestore.instance.collection('resumes').add({
        ..._resume.toFirestore(),
        'userId': user.uid,
        'userEmail': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showAppSnack(context, 'Resume saved! Find it under My Resumes.');
        widget.onNavigate('my-resumes');
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Failed to save resume.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;

    final profileStats = _profile == null
        ? null
        : [
            ('Name & Contact',
                (_profile!['name'] ?? '') != '' &&
                    (_profile!['email'] ?? '') != ''),
            ('Education',
                (_profile!['educationEntries'] as List?)?.isNotEmpty ??
                    (_profile!['education'] ?? '') != ''),
            ('Experience',
                (_profile!['experienceEntries'] as List?)?.isNotEmpty ??
                    (_profile!['experience'] ?? '') != ''),
            ('Projects',
                (_profile!['projectEntries'] as List?)?.isNotEmpty ??
                    (_profile!['projects'] ?? '') != ''),
            ('Skills', (_profile!['technicalSkills'] ?? '') != ''),
            ('Achievements',
                (_profile!['achievementEntries'] as List?)?.isNotEmpty ??
                    (_profile!['achievements'] ?? '') != ''),
          ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const PageHeader(
          title: 'Resume Builder',
          subtitle:
              'Data is pulled from your profile. Use AI to tailor it for a specific role.',
        ),
        const SizedBox(height: 16),

        // ── Profile completeness ──
        if (profileStats != null) ...[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Profile Data',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => widget.onNavigate('profile'),
                      child: const Text('Edit Profile →',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.blue)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: profileStats.map((stat) {
                    final filled = stat.$2 == true;
                    final color = filled
                        ? AppColors.success
                        : scheme.onSurface.withValues(alpha: 0.3);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: filled
                            ? AppColors.success.withValues(alpha: 0.08)
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: filled
                                ? AppColors.success.withValues(alpha: 0.25)
                                : scheme.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(stat.$1,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: filled
                                      ? AppColors.success
                                      : scheme.onSurface
                                          .withValues(alpha: 0.45))),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'The resume is built from your profile. Fill in more sections for a richer resume.',
                  style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurface.withValues(alpha: 0.35)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── AI tailor ──
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text('AI',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Tailor for a Job',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Paste the job description and the AI will rewrite your resume to match the role, highlighting relevant keywords.',
                style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurface.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 14),
              const FieldLabel('Target Company'),
              TextField(
                controller: _company,
                decoration:
                    const InputDecoration(hintText: 'e.g. Google, Vercel…'),
              ),
              const SizedBox(height: 12),
              const FieldLabel('Job Description'),
              TextField(
                controller: _jobDescription,
                maxLines: 6,
                decoration:
                    const InputDecoration(hintText: 'Paste the full JD here…'),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _generating ? null : _generate,
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text(_generating
                    ? 'ANALYZING JD & TAILORING…'
                    : 'GENERATE TAILORED RESUME'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── Matched keywords ──
        if (_keywords.isNotEmpty) ...[
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Matched Keywords',
                    style: TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'These keywords from the JD are highlighted in your resume preview.',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurface.withValues(alpha: 0.4)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: _keywords
                      .map((kw) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF3A8)
                                  .withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(kw,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7A5C00))),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── ATS + preview ──
        AtsPanel(data: _resume, keywords: _keywords),
        const SizedBox(height: 12),
        Row(
          children: [
            const FieldLabel('Live Preview'),
            const Spacer(),
            Pill(label: 'A4 Format', color: scheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
        const SizedBox(height: 6),
        ResumePreview(data: _resume, keywords: _keywords),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'SAVING…' : 'SAVE RESUME'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
