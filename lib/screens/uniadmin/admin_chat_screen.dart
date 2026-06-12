import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat_widgets.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'student_view_screen.dart';

/// Admin side of one support chat: full thread (incl. internal notes),
/// claim/close controls, and a student-context sidebar so admins never
/// have to ask "what's your roll number?".
class AdminChatScreen extends StatefulWidget {
  final String chatId;
  final String studentName;

  const AdminChatScreen({
    super.key,
    required this.chatId,
    required this.studentName,
  });

  @override
  State<AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  bool _markScheduled = false;

  @override
  void initState() {
    super.initState();
    ChatService.markSeen(widget.chatId, asAdmin: true);
  }

  void _scheduleMarkSeen() {
    if (_markScheduled) return;
    _markScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ChatService.markSeen(widget.chatId, asAdmin: true);
      _markScheduled = false;
    });
  }

  Future<void> _send(String text,
      {Uint8List? fileBytes, String? fileName, bool internal = false}) async {
    final auth = context.read<AuthService>();
    await ChatService.sendMessage(
      chatId: widget.chatId,
      auth: auth,
      text: text,
      fileBytes: fileBytes,
      fileName: fileName,
      internal: internal,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      endDrawer: _StudentContextSidebar(studentId: widget.chatId),
      appBar: AppBar(
        title: Text(widget.studentName),
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: ChatService.chatRef(widget.chatId).snapshots(),
            builder: (context, snap) {
              final status =
                  (snap.data?.data()?['status'] as String?) ?? 'open';
              return PopupMenuButton<String>(
                onSelected: (action) => action == 'close'
                    ? ChatService.close(widget.chatId)
                    : ChatService.reopen(widget.chatId),
                itemBuilder: (_) => [
                  if (status != 'closed')
                    const PopupMenuItem(
                        value: 'close', child: Text('Close chat')),
                  if (status == 'closed')
                    const PopupMenuItem(
                        value: 'reopen', child: Text('Reopen chat')),
                ],
              );
            },
          ),
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Student profile',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.person_outline_rounded, size: 21),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Status banner (only when closed) ──
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ChatService.chatRef(widget.chatId).snapshots(),
              builder: (context, snap) {
                final status =
                    (snap.data?.data()?['status'] as String?) ?? 'open';
                if (status != 'closed') return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: AppColors.green.withValues(alpha: 0.1),
                  child: const Text('This conversation is closed',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.green)),
                );
              },
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ChatService.messagesRef(widget.chatId)
                    .orderBy('createdAt', descending: true)
                    .limit(300)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Text('Chat unavailable',
                          style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4))),
                    );
                  }
                  if (!snap.hasData) return const CenteredLoader();
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Center(
                      child: Text('No messages yet',
                          style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  scheme.onSurface.withValues(alpha: 0.4))),
                    );
                  }
                  if (docs.any((d) =>
                      d.data()['seenByAdmin'] == false &&
                      d.data()['internal'] != true)) {
                    _scheduleMarkSeen();
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final m = docs[i].data();
                      final mine = m['senderRole'] == 'admin';
                      return MessageBubble(
                        data: m,
                        mine: mine,
                        seen: m['seenByStudent'] == true,
                      );
                    },
                  );
                },
              ),
            ),
            ChatComposer(
              onSend: _send,
              showInternalToggle: true,
              hint: 'Reply to ${widget.studentName}…',
            ),
          ],
        ),
      ),
    );
  }
}

/// Slide-in sidebar with the student's profile and application history.
class _StudentContextSidebar extends StatelessWidget {
  final String studentId;
  const _StudentContextSidebar({required this.studentId});

  static double? _cgpaOf(Map<String, dynamic> data) {
    for (final entry in (data['educationEntries'] as List? ?? [])) {
      if (entry is Map && entry['cgpa'] != null) {
        final v = double.tryParse(
            entry['cgpa'].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        if (v != null) return v;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      width: 304,
      child: SafeArea(
        child: FutureBuilder<List<dynamic>>(
          future: Future.wait([
            FirebaseFirestore.instance
                .collection('users')
                .doc(studentId)
                .get(),
            FirebaseFirestore.instance
                .collection('applications')
                .where('userId', isEqualTo: studentId)
                .get()
                .then<QuerySnapshot<Map<String, dynamic>>?>((v) => v)
                .catchError((_) => null),
          ]),
          builder: (context, snap) {
            if (!snap.hasData) return const CenteredLoader();
            final user = (snap.data![0]
                        as DocumentSnapshot<Map<String, dynamic>>)
                    .data() ??
                {};
            final apps =
                (snap.data![1] as QuerySnapshot<Map<String, dynamic>>?)
                        ?.docs
                        .map((d) => d.data())
                        .toList() ??
                    [];
            apps.sort((a, b) =>
                (toDate(b['appliedAt'])?.millisecondsSinceEpoch ?? 0)
                    .compareTo(
                        toDate(a['appliedAt'])?.millisecondsSinceEpoch ??
                            0));

            final name = (user['name'] as String?) ?? 'Student';
            final cgpa = _cgpaOf(user);
            final education =
                (user['educationEntries'] as List? ?? []).firstOrNull;
            final degree =
                education is Map ? education['degree']?.toString() : null;
            final placed =
                apps.any((a) => a['status'] == 'selected');

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor:
                          AppColors.accent.withValues(alpha: 0.13),
                      backgroundImage: user['photoURL'] != null
                          ? NetworkImage(user['photoURL'] as String)
                          : null,
                      child: user['photoURL'] == null
                          ? Text(name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accent))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800)),
                          if ((user['email'] ?? '') != '')
                            Text(user['email'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.45))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(
                        label: placed ? 'Placed' : 'Unplaced',
                        color:
                            placed ? AppColors.success : AppColors.amber),
                    if ((user['rollNumber'] ?? user['studentId'] ?? '') !=
                        '')
                      Pill(
                          label:
                              'Roll ${user['rollNumber'] ?? user['studentId']}',
                          color: AppColors.accent),
                    if (cgpa != null)
                      Pill(label: 'CGPA $cgpa', color: AppColors.blue),
                    if (user['verified'] == true)
                      const Pill(
                          label: 'Verified', color: AppColors.success),
                  ],
                ),
                if (degree != null && degree.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.school_outlined,
                          size: 13,
                          color: scheme.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(degree,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurface
                                    .withValues(alpha: 0.6))),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => StudentViewScreen(
                            studentId: studentId, data: user)),
                  ),
                  icon: const Icon(Icons.open_in_full_rounded, size: 13),
                  label: const Text('FULL PROFILE',
                      style: TextStyle(fontSize: 11, letterSpacing: 0.6)),
                ),
                const SizedBox(height: 20),
                const FieldLabel('Applications'),
                if (apps.isEmpty)
                  Text('No applications yet',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.4)))
                else
                  ...apps.take(10).map((a) {
                    final status = (a['status'] as String?) ?? 'pending';
                    final color = switch (status) {
                      'selected' => AppColors.success,
                      'rejected' => AppColors.danger,
                      'shortlisted' => AppColors.blue,
                      _ => AppColors.amber,
                    };
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scheme.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              (a['internshipRole'] as String?) ??
                                  (a['companyName'] as String?) ??
                                  'Application',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                    (a['companyName'] as String?) ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.45))),
                              ),
                              Pill(label: status, color: color),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
