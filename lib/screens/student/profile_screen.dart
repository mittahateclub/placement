import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/student_filters.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';

/// Student profile editor. Writes both the structured entry arrays and the
/// serialized string fields so resume generation stays compatible with web.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;
  double? _uploadProgress;
  String? _photoUrl;

  // Simple fields
  final _name = TextEditingController();
  final _rollNumber = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _title = TextEditingController();
  final _bio = TextEditingController();
  final _linkedin = TextEditingController();
  final _github = TextEditingController();
  final _skills = TextEditingController();
  final _coursework = TextEditingController();

  /// Branch / department — used by admins to target events.
  String? _branch;

  // Structured entries — stored as mutable maps matching the web field names.
  List<Map<String, String>> _education = [];
  List<Map<String, String>> _experience = [];
  List<Map<String, String>> _projects = [];
  List<Map<String, String>> _achievements = [];
  List<Map<String, String>> _positions = [];
  List<Map<String, String>> _extracurriculars = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _rollNumber, _phone, _email, _title, _bio,
      _linkedin, _github, _skills, _coursework,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, String>> _entries(dynamic raw) => (raw as List? ?? [])
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
      .toList();

  Future<void> _fetch() async {
    final auth = context.read<AuthService>();
    final user = auth.user;
    if (user == null) return;
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      final d = doc.data() ?? {};
      _name.text = (d['name'] as String?) ?? '';
      _rollNumber.text = (d['rollNumber'] as String?) ?? '';
      _phone.text = (d['phone'] as String?) ?? '';
      _email.text = (d['email'] as String?) ?? user.email ?? '';
      _title.text = (d['title'] as String?) ?? '';
      _bio.text = (d['bio'] as String?) ?? '';
      _linkedin.text = (d['linkedinUrl'] as String?) ?? '';
      _github.text = (d['githubUrl'] as String?) ?? '';
      _skills.text = (d['technicalSkills'] as String?) ?? '';
      _coursework.text = (d['relevantCoursework'] as String?) ?? '';
      _photoUrl = d['photoURL'] as String?;
      final branch = d['branch'] as String?;
      _branch = kBranches.contains(branch) ? branch : null;
      _education = _entries(d['educationEntries']);
      _experience = _entries(d['experienceEntries']);
      _projects = _entries(d['projectEntries']);
      _achievements = _entries(d['achievementEntries']);
      _positions = _entries(d['positionEntries']);
      _extracurriculars = _entries(d['extracurricularEntries']);
    } catch (_) {
      // Show whatever we have.
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Serializers (same output as the web profile page) ──

  static String _range(Map<String, String> e) {
    final from = e['fromDate'] ?? '';
    final to = e['toDate'] ?? '';
    if (from.isNotEmpty && to.isNotEmpty) return '$from – $to';
    if (from.isNotEmpty) return '$from – Present';
    return to;
  }

  static String _joinNonEmpty(List<String> parts, [String sep = ' | ']) =>
      parts.where((p) => p.trim().isNotEmpty).join(sep);

  String _serializeEducation() => _education
      .where((e) => (e['institution'] ?? '').isNotEmpty || (e['degree'] ?? '').isNotEmpty)
      .map((e) => _joinNonEmpty([
            e['institution'] ?? '', e['location'] ?? '', e['degree'] ?? '',
            _range(e),
            if ((e['cgpa'] ?? '').isNotEmpty) 'CGPA: ${e['cgpa']}' else '',
          ]))
      .join('\n');

  String _serializeExperience() => _experience
      .where((e) => (e['company'] ?? '').isNotEmpty || (e['role'] ?? '').isNotEmpty)
      .map((e) => _joinNonEmpty([
            _joinNonEmpty([e['company'] ?? '', e['role'] ?? '', _range(e)]),
            e['location'] ?? '',
            e['description'] ?? '',
          ], '\n'))
      .join('\n\n');

  String _serializeProjects() => _projects
      .where((e) => (e['title'] ?? '').isNotEmpty)
      .map((e) => _joinNonEmpty([
            _joinNonEmpty([e['title'] ?? '', e['techStack'] ?? '', _range(e)]),
            e['location'] ?? '',
            e['description'] ?? '',
            e['link'] ?? '',
          ], '\n'))
      .join('\n\n');

  String _serializeAchievements() => _achievements
      .where((e) => (e['title'] ?? '').isNotEmpty)
      .map((e) => _joinNonEmpty(
          [e['title'] ?? '', e['issuer'] ?? '', e['location'] ?? '', _range(e)]))
      .join('\n');

  String _serializePositions() => _positions
      .where((e) => (e['title'] ?? '').isNotEmpty)
      .map((e) => _joinNonEmpty([
            e['title'] ?? '', e['organization'] ?? '',
            e['location'] ?? '', _range(e),
          ]))
      .join('\n');

  String _serializeExtracurriculars() => _extracurriculars
      .where((e) => (e['activity'] ?? '').isNotEmpty)
      .map((e) => _joinNonEmpty([
            e['activity'] ?? '', e['role'] ?? '', e['location'] ?? '',
            _range(e), e['description'] ?? '',
          ]))
      .join('\n');

  Future<void> _save() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _db.collection('users').doc(user.uid).update({
        'name': _name.text.trim(),
        'rollNumber': _rollNumber.text.trim(),
        'branch': _branch,
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'title': _title.text.trim(),
        'bio': _bio.text.trim(),
        'linkedinUrl': _linkedin.text.trim(),
        'githubUrl': _github.text.trim(),
        'technicalSkills': _skills.text.trim(),
        'relevantCoursework': _coursework.text.trim(),
        'educationEntries': _education,
        'experienceEntries': _experience,
        'projectEntries': _projects,
        'achievementEntries': _achievements,
        'positionEntries': _positions,
        'extracurricularEntries': _extracurriculars,
        'education': _serializeEducation(),
        'experience': _serializeExperience(),
        'projects': _serializeProjects(),
        'achievements': _serializeAchievements(),
        'positions': _serializePositions(),
        'extracurriculars': _serializeExtracurriculars(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        showAppSnack(context, 'Profile updated successfully!');
        await context.read<AuthService>().refreshProfile();
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Failed to update profile.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePhoto() async {
    final user = context.read<AuthService>().user;
    if (user == null) return;
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadProgress = 0);
    try {
      final ref =
          FirebaseStorage.instance.ref('profile_pictures/${user.uid}');
      final task = ref.putFile(File(picked.path));
      task.snapshotEvents.listen((s) {
        if (mounted && s.totalBytes > 0) {
          setState(
              () => _uploadProgress = s.bytesTransferred / s.totalBytes);
        }
      });
      await task;
      final url = await ref.getDownloadURL();
      await _db.collection('users').doc(user.uid).update({'photoURL': url});
      if (mounted) {
        setState(() => _photoUrl = url);
        showAppSnack(context, 'Profile photo updated!');
        await context.read<AuthService>().refreshProfile();
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'Failed to upload image.', error: true);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const CenteredLoader();
    final scheme = Theme.of(context).colorScheme;
    final user = context.watch<AuthService>().user;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Identity card ──
        SurfaceCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GestureDetector(
                onTap: _uploadProgress == null ? _changePhoto : null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor:
                          AppColors.accent.withValues(alpha: 0.15),
                      backgroundImage:
                          _photoUrl != null ? NetworkImage(_photoUrl!) : null,
                      child: _photoUrl == null
                          ? Text(
                              (user?.email ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent),
                            )
                          : null,
                    ),
                    if (_uploadProgress != null)
                      CircularProgressIndicator(value: _uploadProgress),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: scheme.surfaceContainer, width: 2),
                        ),
                        child: const Icon(Icons.photo_camera_outlined,
                            size: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _name.text.isNotEmpty
                    ? _name.text
                    : user?.email?.split('@').first ?? 'Student',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(
                _title.text.isNotEmpty ? _title.text : 'Student Account',
                style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurface.withValues(alpha: 0.5)),
              ),
              if (_rollNumber.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                Pill(label: 'Roll · ${_rollNumber.text}', color: AppColors.accent),
              ],
              if (_linkedin.text.isNotEmpty || _github.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_linkedin.text.isNotEmpty)
                      IconButton(
                        onPressed: () => launchUrl(
                            Uri.parse(_linkedin.text),
                            mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.link_rounded,
                            color: Color(0xFF0A66C2)),
                        tooltip: 'LinkedIn',
                      ),
                    if (_github.text.isNotEmpty)
                      IconButton(
                        onPressed: () => launchUrl(Uri.parse(_github.text),
                            mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.code_rounded),
                        tooltip: 'GitHub',
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Personal details ──
        _SectionCard(title: 'Personal Details', children: [
          _field('Full Name', _name),
          _field('Roll Number', _rollNumber),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FieldLabel('Branch / Department'),
                DropdownButtonFormField<String?>(
                  initialValue: _branch,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not set',
                          style: TextStyle(fontSize: 13.5)),
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
              ],
            ),
          ),
          _field('Phone Number', _phone, keyboard: TextInputType.phone),
          _field('Contact Email', _email, keyboard: TextInputType.emailAddress),
          _field('Professional Title', _title,
              hint: 'e.g. CS Student | Aspiring SDE'),
          _field('Bio', _bio, maxLines: 3),
        ]),
        const SizedBox(height: 12),

        // ── Web presence ──
        _SectionCard(title: 'Web Presence', children: [
          _field('LinkedIn URL', _linkedin,
              hint: 'https://linkedin.com/in/yourname',
              keyboard: TextInputType.url),
          _field('GitHub URL', _github,
              hint: 'https://github.com/yourusername',
              keyboard: TextInputType.url),
        ]),
        const SizedBox(height: 12),

        // ── Skills & coursework ──
        _SectionCard(title: 'Skills & Coursework', children: [
          _field('Technical Skills (comma separated)', _skills,
              hint: 'React, Flutter, Python, SQL', maxLines: 2),
          _field('Relevant Coursework (comma separated)', _coursework,
              hint: 'Data Structures, DBMS, OS', maxLines: 2),
        ]),
        const SizedBox(height: 12),

        // ── Structured portfolio sections ──
        _EntriesSection(
          title: 'Education',
          entries: _education,
          fields: const [
            ('institution', 'Institution', false),
            ('degree', 'Degree / Program', false),
            ('location', 'Location (optional)', false),
            ('cgpa', 'CGPA / Percentage (optional)', false),
            ('fromDate', 'From (e.g. Aug 2022)', false),
            ('toDate', 'To (e.g. May 2026)', false),
          ],
          onChanged: () => setState(() {}),
        ),
        _EntriesSection(
          title: 'Experience',
          entries: _experience,
          fields: const [
            ('company', 'Company / Organization', false),
            ('role', 'Role / Title', false),
            ('location', 'Location (optional)', false),
            ('fromDate', 'From (e.g. Jun 2025)', false),
            ('toDate', 'To (e.g. Aug 2025)', false),
            ('description', 'Description / responsibilities', true),
          ],
          onChanged: () => setState(() {}),
        ),
        _EntriesSection(
          title: 'Projects',
          entries: _projects,
          fields: const [
            ('title', 'Project Title', false),
            ('techStack', 'Tech Stack (e.g. Flutter, Firebase)', false),
            ('link', 'Link (optional)', false),
            ('fromDate', 'From (optional)', false),
            ('toDate', 'To (optional)', false),
            ('description', 'Description / highlights', true),
          ],
          onChanged: () => setState(() {}),
        ),
        _EntriesSection(
          title: 'Achievements & Certifications',
          entries: _achievements,
          fields: const [
            ('title', 'Title / Award', false),
            ('issuer', 'Issuer / Organization (optional)', false),
            ('location', 'Location (optional)', false),
            ('fromDate', 'From (optional)', false),
            ('toDate', 'To (optional)', false),
          ],
          onChanged: () => setState(() {}),
        ),
        _EntriesSection(
          title: 'Positions of Responsibility',
          entries: _positions,
          fields: const [
            ('title', 'Title / Role', false),
            ('organization', 'Organization / Club', false),
            ('location', 'Location (optional)', false),
            ('fromDate', 'From (optional)', false),
            ('toDate', 'To (optional)', false),
          ],
          onChanged: () => setState(() {}),
        ),
        _EntriesSection(
          title: 'Extracurriculars / Activities',
          entries: _extracurriculars,
          fields: const [
            ('activity', 'Activity', false),
            ('role', 'Role (optional)', false),
            ('location', 'Location (optional)', false),
            ('fromDate', 'From (optional)', false),
            ('toDate', 'To (optional)', false),
            ('description', 'Description (optional)', false),
          ],
          onChanged: () => setState(() {}),
        ),

        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'SAVING…' : 'SAVE PROFILE CHANGES'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller,
      {String? hint, int maxLines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboard,
            decoration: InputDecoration(hintText: hint),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

/// Expandable card with add/remove entry rows for one portfolio section.
class _EntriesSection extends StatefulWidget {
  final String title;
  final List<Map<String, String>> entries;

  /// (key, label, multiline)
  final List<(String, String, bool)> fields;
  final VoidCallback onChanged;

  const _EntriesSection({
    required this.title,
    required this.entries,
    required this.fields,
    required this.onChanged,
  });

  @override
  State<_EntriesSection> createState() => _EntriesSectionState();
}

class _EntriesSectionState extends State<_EntriesSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    if (widget.entries.isNotEmpty)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: const BoxDecoration(
                            color: AppColors.success, shape: BoxShape.circle),
                      ),
                    Icon(
                      _open
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: scheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    for (final (i, entry) in widget.entries.indexed)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                FieldLabel('Entry ${i + 1}'),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    widget.entries.removeAt(i);
                                    widget.onChanged();
                                  },
                                  child: const Text('Remove',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.danger)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            for (final (key, label, multiline)
                                in widget.fields)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TextFormField(
                                  initialValue: entry[key] ?? '',
                                  maxLines: multiline ? 3 : 1,
                                  style: const TextStyle(fontSize: 13),
                                  decoration:
                                      InputDecoration(hintText: label),
                                  onChanged: (v) => entry[key] = v,
                                ),
                              ),
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        widget.entries.add({
                          for (final (key, _, _) in widget.fields) key: '',
                        });
                        widget.onChanged();
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text('Add ${widget.title.split(' ').first}'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
