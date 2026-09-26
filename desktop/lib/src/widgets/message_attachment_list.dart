import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';

class MessageAttachmentList extends StatefulWidget {
  const MessageAttachmentList({
    super.key,
    required this.state,
    required this.parentPath,
    required this.attachments,
  });

  final AppState state;
  final String parentPath;
  final List<MessageAttachment> attachments;

  @override
  State<MessageAttachmentList> createState() => _MessageAttachmentListState();
}

class _MessageAttachmentListState extends State<MessageAttachmentList> {
  final Map<String, Future<Uint8List>> _previews = {};

  Future<void> _save(MessageAttachment attachment) async {
    try {
      final bytes = await widget.state.api.messageAttachmentBytes(
        widget.parentPath,
        attachment.id,
      );
      if (Platform.isAndroid) {
        await const MethodChannel('boohtacord/download')
            .invokeMethod<bool>('save', {
              'filename': attachment.originalName,
              'mimeType': _mimeType(attachment.originalName),
              'bytes': bytes,
            });
        return;
      }
      final location = await getSaveLocation(
        suggestedName: attachment.originalName,
      );
      if (location == null) return;
      await File(location.path).writeAsBytes(bytes, flush: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось скачать вложение.')),
        );
      }
    }
  }

  String _mimeType(String name) => switch (name.split('.').last.toLowerCase()) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'zip' => 'application/zip',
    _ => 'application/octet-stream',
  };

  String _sizeLabel(int bytes) {
    if (bytes < 1000) return '$bytes Б';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(1)} КБ';
    return '${(bytes / 1000000).toStringAsFixed(1)} МБ';
  }

  bool _isImage(String name) =>
      RegExp(r'\.(png|jpe?g|gif)$', caseSensitive: false).hasMatch(name);

  @override
  Widget build(BuildContext context) {
    if (widget.attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final attachment in widget.attachments)
            InkWell(
              onTap: () => _save(attachment),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF202329),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF363A42)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isImage(attachment.originalName))
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: FutureBuilder<Uint8List>(
                            future: _previews.putIfAbsent(
                              attachment.id,
                              () => widget.state.api.messageAttachmentBytes(
                                widget.parentPath,
                                attachment.id,
                                preview: true,
                              ),
                            ),
                            builder: (context, snapshot) => snapshot.hasData
                                ? Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.broken_image_outlined),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_outlined, size: 24),
                                  ),
                          ),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.insert_drive_file_outlined),
                      ),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            attachment.originalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            _sizeLabel(attachment.sizeBytes),
                            style: const TextStyle(
                              color: Color(0xFF9AA0AA),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.download_outlined, size: 17),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
