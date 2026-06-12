import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/format.dart';
import '../../services/auth_service.dart';
import '../../widgets/common.dart';
import '../../widgets/loading_dots.dart';
import 'admin_chat_screen.dart';

/// Top-right app-bar shortcut to the Support Inbox with a live badge
/// counting chats that have unread student messages.
class InboxAppBarButton extends StatelessWidget {
  final VoidCallback onOpen;
  const InboxAppBarButton({super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final universityId = context.read<AuthService>().universityId;
    if (universityId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('universityId', isEqualTo: universityId)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        final unreadChats = snap.data?.docs
                .where((d) =>
                    ((d.data()['adminUnread'] as num?)?.toInt() ?? 0) > 0)
                .length ??
            0;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            IconButton(
              tooltip: 'Support Inbox',
              onPressed: onOpen,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
            ),
            if (unreadChats > 0)
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
                    unreadChats > 9 ? '9+' : '$unreadChats',
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

/// Shared support inbox — every student chat for the university, newest
/// first. Any admin can open a chat and reply directly.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final universityId = auth.universityId;
    final uid = auth.user?.uid;

    if (universityId == null || uid == null) {
      return const EmptyState(
        icon: Icons.forum_outlined,
        title: 'No university',
        subtitle: 'Your profile has no university attached',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: PageHeader(
            title: 'Support Inbox',
            subtitle: 'Student messages land here — open a chat to reply',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Equality filter only — no composite index required; sorted
            // by recency client-side below.
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('universityId', isEqualTo: universityId)
                .limit(200)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Inbox unavailable',
                  subtitle: 'Check your connection and try again',
                );
              }
              if (!snap.hasData) return const CenteredLoader();

              final docs = snap.data!.docs.toList()
                ..sort((a, b) =>
                    (toDate(b.data()['lastMessageAt'])
                            ?.millisecondsSinceEpoch ??
                        0)
                        .compareTo(toDate(a.data()['lastMessageAt'])
                                ?.millisecondsSinceEpoch ??
                            0));

              if (docs.isEmpty) {
                return const EmptyState(
                  icon: Icons.mark_chat_read_outlined,
                  title: 'No conversations yet',
                  subtitle: 'Student messages appear here in real time',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChatTile(
                      chatId: doc.id,
                      data: doc.data(),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String chatId;
  final Map<String, dynamic> data;

  const _ChatTile({
    required this.chatId,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = (data['studentName'] as String?) ?? 'Student';
    final status = (data['status'] as String?) ?? 'open';
    final unread = (data['adminUnread'] as num?)?.toInt() ?? 0;
    final lastText = (data['lastMessageText'] as String?) ?? '';
    final lastAt = toDate(data['lastMessageAt']);

    return SurfaceCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                AdminChatScreen(chatId: chatId, studentName: name)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent.withValues(alpha: 0.13),
            child: Text(
              name.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700)),
                    ),
                    Text(timeAgo(lastAt),
                        style: TextStyle(
                            fontSize: 10.5,
                            color:
                                scheme.onSurface.withValues(alpha: 0.4))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastText.isEmpty ? 'No messages yet' : lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: scheme.onSurface.withValues(
                                alpha: unread > 0 ? 0.8 : 0.45)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text('$unread',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: scheme.onPrimary)),
                      ),
                  ],
                ),
                if (status == 'closed') ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Pill(label: 'Closed', color: AppColors.green),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
