import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/resume_data.dart';
import '../../services/resume_pdf.dart';
import '../../widgets/ats_panel.dart';
import '../../widgets/common.dart';
import '../../widgets/resume_preview.dart';

/// View a saved resume: ATS score, A4 preview, inline editor, PDF export.
class ResumeDetailScreen extends StatefulWidget {
  final ResumeData resume;
  const ResumeDetailScreen({super.key, required this.resume});

  @override
  State<ResumeDetailScreen> createState() => _ResumeDetailScreenState();
}

class _ResumeDetailScreenState extends State<ResumeDetailScreen> {
  late ResumeData _draft;
  bool _saving = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.resume.copy();
  }

  Future<void> _save() async {
    if (_draft.id == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('resumes')
          .doc(_draft.id)
          .update({
        ..._draft.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) showAppSnack(context, 'Changes saved!');
    } catch (_) {
      if (mounted) showAppSnack(context, 'Failed to save.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await ResumePdf.share(_draft);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to generate PDF.', error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _openEditor() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditorSheet(draft: _draft),
    );
    setState(() {}); // refresh preview with edits
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_draft.targetCompany.isEmpty
            ? 'Resume'
            : _draft.targetCompany),
        actions: [
          IconButton(
            tooltip: 'Edit content',
            onPressed: _openEditor,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Save changes',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 20),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AtsPanel(data: _draft, keywords: _draft.keywords),
            const SizedBox(height: 14),
            ResumePreview(data: _draft, keywords: _draft.keywords),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _exporting ? null : _export,
        icon: _exporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.download_rounded),
        label: Text(_exporting ? 'Generating…' : 'Download PDF'),
      ),
    );
  }
}

/// Bottom-sheet form editing every resume field; writes into the draft.
class _EditorSheet extends StatelessWidget {
  final ResumeData draft;
  const _EditorSheet({required this.draft});

  @override
  Widget build(BuildContext context) {
    final fields = <(String, String Function(), void Function(String), int)>[
      ('Full Name', () => draft.fullName, (v) => draft.fullName = v, 1),
      ('Email', () => draft.email, (v) => draft.email = v, 1),
      ('Phone', () => draft.phone, (v) => draft.phone = v, 1),
      ('Website', () => draft.website, (v) => draft.website = v, 1),
      ('LinkedIn URL', () => draft.linkedin, (v) => draft.linkedin = v, 1),
      ('GitHub URL', () => draft.github, (v) => draft.github = v, 1),
      ('Education', () => draft.education, (v) => draft.education = v, 6),
      ('Experience', () => draft.experience, (v) => draft.experience = v, 8),
      ('Projects', () => draft.projects, (v) => draft.projects = v, 8),
      ('Relevant Coursework', () => draft.coursework,
          (v) => draft.coursework = v, 2),
      ('Technical Skills', () => draft.skills, (v) => draft.skills = v, 4),
      ('Extracurriculars', () => draft.extracurriculars,
          (v) => draft.extracurriculars = v, 3),
      ('Achievements', () => draft.achievements,
          (v) => draft.achievements = v, 3),
      ('Target Company', () => draft.targetCompany,
          (v) => draft.targetCompany = v, 1),
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Text('Edit Resume',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(20, 12, 20,
                  MediaQuery.of(context).viewInsets.bottom + 24),
              children: [
                for (final (label, get, set, lines) in fields) ...[
                  FieldLabel(label),
                  TextFormField(
                    initialValue: get(),
                    maxLines: lines,
                    style: const TextStyle(fontSize: 13),
                    onChanged: set,
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
