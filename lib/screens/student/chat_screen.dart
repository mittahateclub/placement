import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../widgets/chat_widgets.dart';
import '../../widgets/loading_dots.dart';

/// Student side of support chat — instant messaging with the placement cell.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  String? _chatId;
  bool _markScheduled = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _chatId = auth.user?.uid;
    ChatService.ensureChat(auth)
        .then((_) => ChatService.markSeen(_chatId!, asAdmin: false))
        .catchError((_) {}); // surfaces as an empty thread until rules allow
  }

  /// Mark incoming admin messages as read (throttled per frame).
  void _scheduleMarkSeen() {
    if (_markScheduled || _chatId == null) return;
    _markScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ChatService.markSeen(_chatId!, asAdmin: false);
      _markScheduled = false;
    });
  }

  Future<void> _send(String text,
      {Uint8List? fileBytes, String? fileName, bool internal = false}) async {
    final auth = context.read<AuthService>();
    final chatId = _chatId;
    if (chatId == null) return;
    // Sending into a closed conversation reopens it for the admins.
    final chat = await ChatService.chatRef(chatId).get();
    if (chat.data()?['status'] == 'closed') {
      await ChatService.reopen(chatId);
    }
    await ChatService.sendMessage(
      chatId: chatId,
      auth: auth,
      text: text,
      fileBytes: fileBytes,
      fileName: fileName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final chatId = _chatId;
    if (chatId == null) {
      return const Scaffold(body: CenteredLoader());
    }
    final uid = chatId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Placement Support'),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: ChatService.chatRef(chatId).snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final status = (data?['status'] as String?) ?? 'open';
                final label = switch (status) {
                  'claimed' =>
                    'with ${data?['claimedByName'] ?? 'an admin'}',
                  'closed' => 'conversation closed',
                  _ => 'an admin will reply soon',
                };
                return Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface.withValues(alpha: 0.45)));
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                // Students only ever receive non-internal messages. Equality
                // filter only (no orderBy) so no composite index is needed;
                // sorting happens client-side below.
                stream: ChatService.messagesRef(chatId)
                    .where('internal', isEqualTo: false)
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
                  // Newest first; just-sent messages have a pending
                  // serverTimestamp (null), so treat them as newest.
                  final docs = snap.data!.docs.toList()
                    ..sort((a, b) {
                      final at = toDate(a.data()['createdAt'])
                              ?.millisecondsSinceEpoch ??
                          1 << 52;
                      final bt = toDate(b.data()['createdAt'])
                              ?.millisecondsSinceEpoch ??
                          1 << 52;
                      return bt.compareTo(at);
                    });
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 36,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.25)),
                            const SizedBox(height: 12),
                            const Text('Ask the placement cell anything',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                              'Job postings, document verification, interview schedules — an admin will reply here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: scheme.onSurface
                                      .withValues(alpha: 0.45)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  if (docs.any((d) =>
                      d.data()['seenByStudent'] == false)) {
                    _scheduleMarkSeen();
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final m = docs[i].data();
                      final mine = m['senderId'] == uid;
                      return MessageBubble(
                        data: m,
                        mine: mine,
                        seen: m['seenByAdmin'] == true,
                      );
                    },
                  );
                },
              ),
            ),
            ChatComposer(
                onSend: _send, hint: 'Ask about jobs, documents, interviews…'),
          ],
        ),
      ),
    );
  }
}

/// App-bar chat action for students — a plain top-right icon (no background
/// box) with a live unread badge.
class ChatAppBarButton extends StatelessWidget {
  const ChatAppBarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = context.read<AuthService>().user?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ChatService.chatRef(uid).snapshots(),
      builder: (context, snap) {
        final unread =
            (snap.data?.data()?['studentUnread'] as num?)?.toInt() ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: 'Placement Support',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatScreen()),
              ),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
            ),
            if (unread > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 15),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.surface, width: 1.5),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
