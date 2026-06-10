import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../models/resume_data.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'resume_detail_screen.dart';

/// Saved resumes: list, upload an existing PDF/DOC, open, delete, export.
class MyResumesScreen extends StatefulWidget {
  final void Function(String id) onNavigate;
  const MyResumesScreen({super.key, required this.onNavigate});

  @override
  State<MyResumesScreen> createState() => _MyResumesScreenState();
}

class _MyResumesScreenState extends State<MyResumesScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  bool _uploading = false;
  String? _deletingId;
  List<ResumeData> _resumes = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final email = context.read<AuthService>().user?.email;
    if (email == null) return;
    try {
      final snap = await _db
          .collection('resumes')
          .where('userEmail', isEqualTo: email)
          .get();
      final list = snap.docs.map(ResumeData.fromDoc).toList()
        ..sort((a, b) => (b.updatedAt?.millisecondsSinceEpoch ?? 0)
            .compareTo(a.updatedAt?.millisecondsSinceEpoch ?? 0));
      if (mounted) {
        setState(() {
          _resumes = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadExisting() async {
    final user = context.read<AuthService>().user;
    if (user == null || user.email == null) return;

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    final file = picked?.files.single;
    if (file == null || file.path == null) return;
    if (file.size > 6 * 1024 * 1024) {
      if (mounted) {
        showAppSnack(context, 'File size must be under 6MB.', error: true);
      }
      return;
    }

    setState(() => _uploading = true);
    try {
      final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path =
          'uploaded_resumes/${user.uid}/${DateTime.now().millisecondsSinceEpoch}-$safeName';
      final ref = FirebaseStorage.instance.ref(path);
      await ref.putFile(File(file.path!));
      final url = await ref.getDownloadURL();

      await _db.collection('resumes').add({
        ...ResumeData(email: user.email!).toFirestore(),
        'targetCompany': 'Uploaded Resume',
        'uploadedFileUrl': url,
        'uploadedFileName': file.name,
        'uploadedFileType': file.extension ?? '',
        'userId': user.uid,
        'userEmail': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _fetch();
      if (mounted) showAppSnack(context, 'Resume uploaded!');
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to upload resume.', error: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _delete(ResumeData resume) async {
    if (resume.id == null) return;
    final confirmed = await confirmDialog(
      context,
      title: 'Delete resume?',
      message: 'This permanently removes "${resume.targetCompany.isEmpty ? 'this resume' : resume.targetCompany}". This action cannot be undone.',
    );
    if (!confirmed) return;
    setState(() => _deletingId = resume.id);
    try {
      if ((resume.uploadedFileUrl ?? '').isNotEmpty) {
        try {
          await FirebaseStorage.instance
              .refFromURL(resume.uploadedFileUrl!)
              .delete();
        } catch (_) {
          // Never block resume deletion on storage cleanup.
        }
      }
      await _db.collection('resumes').doc(resume.id).delete();
      setState(() => _resumes.removeWhere((r) => r.id == resume.id));
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Failed to delete resume.', error: true);
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
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
            title: 'My Resumes',
            subtitle: 'Select a resume to preview, edit, or download as PDF.',
          ),
          const SizedBox(height: 16),

          // ── Upload dropzone ──
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _uploading ? null : _uploadExisting,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.4),
                    width: 1.4,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outline),
                      ),
                      child: _uploading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child:
                                  CircularProgressIndicator(strokeWidth: 2.5))
                          : Icon(Icons.upload_rounded,
                              size: 22,
                              color: scheme.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _uploading
                          ? 'Uploading…'
                          : 'Tap to upload an existing resume',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Accepted formats: PDF, DOC, DOCX (max 6MB)',
                      style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withValues(alpha: 0.4)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_resumes.isEmpty)
            SurfaceCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('No resumes found yet',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Upload your previous resume above or create a new one from the builder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => widget.onNavigate('resume-builder'),
                    child: const Text('GO TO BUILDER'),
                  ),
                ],
              ),
            )
          else
            ..._resumes.map((resume) {
              final isUpload = resume.isUploadedFileOnly;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SurfaceCard(
                  onTap: isUpload
                      ? () => launchUrl(Uri.parse(resume.uploadedFileUrl!),
                          mode: LaunchMode.externalApplication)
                      : () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ResumeDetailScreen(resume: resume),
                            ),
                          );
                          _fetch();
                        },
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isUpload
                              ? Icons.attach_file_rounded
                              : Icons.description_outlined,
                          size: 19,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resume.targetCompany.isEmpty
                                  ? 'General Resume'
                                  : resume.targetCompany,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isUpload
                                  ? (resume.uploadedFileName ?? 'Uploaded file')
                                  : '${resume.fullName.isEmpty ? 'Draft' : resume.fullName} · ${formatDate(resume.updatedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.45)),
                            ),
                          ],
                        ),
                      ),
                      if (_deletingId == resume.id)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _delete(resume),
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 18,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4)),
                        ),
                      Icon(
                        isUpload
                            ? Icons.open_in_new_rounded
                            : Icons.chevron_right_rounded,
                        size: 18,
                        color: scheme.onSurface.withValues(alpha: 0.3),
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
