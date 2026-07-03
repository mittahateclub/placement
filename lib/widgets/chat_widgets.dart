import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_colors.dart';
import '../core/format.dart';
import 'common.dart';

/// One chat message. Internal notes render with an amber tint and lock icon
/// (only the admin screens ever pass them in).
class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool mine;

  /// Whether the other side has seen this message (used for receipts on
  /// own messages).
  final bool seen;

  const MessageBubble({
    super.key,
    required this.data,
    required this.mine,
    required this.seen,
  });

  Future<void> _openFile(BuildContext context) async {
    final url = (data['fileUrl'] as String?) ?? '';
    if (url.isEmpty) return;
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showAppSnack(context, 'Could not open the attachment.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final internal = data['internal'] == true;
    final text = (data['text'] as String?) ?? '';
    final fileName = data['fileName'] as String?;
    final time = toDate(data['createdAt']);

    // Own messages get the glossy ink/porcelain fill; internal notes stay
    // amber-tinted; incoming messages sit on a raised surface.
    final brightness = Theme.of(context).brightness;
    final isGlossy = mine && !internal;
    final bg = internal
        ? AppColors.amber.withValues(alpha: 0.12)
        : mine
            ? null
            : scheme.surfaceContainerLow;
    final border = internal
        ? AppColors.amber.withValues(alpha: 0.45)
        : mine
            ? null
            : scheme.outline;
    final fg = isGlossy
        ? AppColors.onGlossy(brightness)
        : scheme.onSurface.withValues(alpha: 0.85);
    final fgMuted = isGlossy
        ? AppColors.onGlossy(brightness).withValues(alpha: 0.55)
        : scheme.onSurface.withValues(alpha: 0.35);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.74),
        decoration: BoxDecoration(
          color: bg,
          gradient: isGlossy ? AppColors.glossy(brightness) : null,
          border: border != null ? Border.all(color: border) : null,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 5),
            bottomRight: Radius.circular(mine ? 5 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (internal)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 10, color: AppColors.amber),
                    const SizedBox(width: 4),
                    Text('INTERNAL NOTE',
                        style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppColors.amber
                                .withValues(alpha: 0.9))),
                  ],
                ),
              ),
            if (fileName != null)
              Padding(
                padding: EdgeInsets.only(bottom: text.isNotEmpty ? 6 : 2),
                child: _AttachmentPreview(
                  fileName: fileName,
                  fileUrl: (data['fileUrl'] as String?) ?? '',
                  onOpen: () => _openFile(context),
                ),
              ),
            if (text.isNotEmpty)
              Text(text,
                  style: TextStyle(fontSize: 13, height: 1.4, color: fg)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeAgo(time),
                    style: TextStyle(fontSize: 9.5, color: fgMuted)),
                if (mine && !internal) ...[
                  const SizedBox(width: 4),
                  Icon(
                    seen ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 12,
                    color: seen ? fg : fgMuted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Visual preview for a chat attachment: image thumbnail for pictures,
/// a file-type chip for documents.
class _AttachmentPreview extends StatelessWidget {
  final String fileName;
  final String fileUrl;
  final VoidCallback onOpen;

  const _AttachmentPreview({
    required this.fileName,
    required this.fileUrl,
    required this.onOpen,
  });

  bool get _isImage =>
      RegExp(r'\.(png|jpe?g|gif|webp)$', caseSensitive: false)
          .hasMatch(fileName);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_isImage && fileUrl.isNotEmpty) {
      return InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            fileUrl,
            width: 210,
            height: 150,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : Container(
                    width: 210,
                    height: 150,
                    color: scheme.surfaceContainerLow,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onSurface.withValues(alpha: 0.3)),
                    ),
                  ),
            errorBuilder: (_, _, _) => _FileChip(
                fileName: fileName, onOpen: onOpen),
          ),
        ),
      );
    }
    return _FileChip(fileName: fileName, onOpen: onOpen);
  }
}

class _FileChip extends StatelessWidget {
  final String fileName;
  final VoidCallback onOpen;

  const _FileChip({required this.fileName, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = fileName.split('.').last.toLowerCase();
    final (icon, color) = switch (ext) {
      'pdf' => (Icons.picture_as_pdf_rounded, AppColors.danger),
      'doc' || 'docx' => (Icons.description_rounded, AppColors.blue),
      'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' => (
          Icons.image_rounded,
          AppColors.green
        ),
      _ => (Icons.insert_drive_file_rounded, AppColors.amber),
    };

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${ext.toUpperCase()} · tap to open',
                    style: TextStyle(
                        fontSize: 9.5,
                        color: scheme.onSurface.withValues(alpha: 0.45)),
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

/// Text input + attachment picker. When [showInternalToggle] is on, a lock
/// chip switches the send into an admin-only internal note.
class ChatComposer extends StatefulWidget {
  final Future<void> Function(String text,
      {Uint8List? fileBytes, String? fileName, bool internal}) onSend;
  final bool showInternalToggle;
  final String hint;

  const ChatComposer({
    super.key,
    required this.onSend,
    this.showInternalToggle = false,
    this.hint = 'Type a message…',
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _sending = false;
  bool _internal = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text, internal: _internal);
      _controller.clear();
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Message failed to send.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach() async {
    final picked = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    final file = picked?.files.firstOrNull;
    if (file == null || file.bytes == null) return;
    if (file.size > 6 * 1024 * 1024) {
      if (mounted) {
        showAppSnack(context, 'File must be under 6 MB.', error: true);
      }
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.onSend(_controller.text.trim(),
          fileBytes: file.bytes, fileName: file.name, internal: _internal);
      _controller.clear();
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Attachment failed to send.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showInternalToggle)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 6),
                  child: FilterChip(
                    selected: _internal,
                    onSelected: (v) => setState(() => _internal = v),
                    avatar: Icon(
                        _internal
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 13,
                        color: _internal
                            ? AppColors.amber
                            : scheme.onSurface.withValues(alpha: 0.45)),
                    label: Text(
                      'Internal note',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _internal
                              ? AppColors.amber
                              : scheme.onSurface.withValues(alpha: 0.55)),
                    ),
                    selectedColor: AppColors.amber.withValues(alpha: 0.15),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _attach,
                  tooltip: 'Attach file',
                  icon: Icon(Icons.attach_file_rounded,
                      size: 20,
                      color: scheme.onSurface.withValues(alpha: 0.5)),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: _internal
                          ? 'Note for other admins…'
                          : widget.hint,
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: _internal
                          ? null
                          : AppColors.glossy(Theme.of(context).brightness),
                      color: _internal ? AppColors.amber : null,
                      shape: BoxShape.circle,
                    ),
                    child: InkWell(
                      onTap: _sending ? null : _sendText,
                      child: Center(
                        child: _sending
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _internal
                                        ? Colors.white
                                        : AppColors.onGlossy(
                                            Theme.of(context).brightness)))
                            : Icon(Icons.send_rounded,
                                size: 18,
                                color: _internal
                                    ? Colors.white
                                    : AppColors.onGlossy(
                                        Theme.of(context).brightness)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
