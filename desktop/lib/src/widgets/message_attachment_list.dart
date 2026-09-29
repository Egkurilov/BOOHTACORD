import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/api_client.dart';

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

  Future<void> _showPreview(MessageAttachment attachment) => showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _ProtectedImagePreview(
      state: widget.state,
      parentPath: widget.parentPath,
      attachment: attachment,
    ),
  );

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
            Container(
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
                    Semantics(
                      button: true,
                      label: 'Открыть изображение ${attachment.originalName}',
                      child: Tooltip(
                        message:
                            'Открыть изображение ${attachment.originalName}',
                        child: InkWell(
                          key: ValueKey('attachment-preview-${attachment.id}'),
                          onTap: () => _showPreview(attachment),
                          borderRadius: BorderRadius.circular(6),
                          child: ClipRRect(
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
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      )
                                    : snapshot.hasError
                                    ? const Icon(Icons.broken_image_outlined)
                                    : const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 24,
                                        ),
                                      ),
                              ),
                            ),
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
                  IconButton(
                    tooltip: 'Скачать ${attachment.originalName}',
                    onPressed: () => _save(attachment),
                    icon: const Icon(Icons.download_outlined, size: 17),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ProtectedImagePreview extends StatefulWidget {
  const _ProtectedImagePreview({
    required this.state,
    required this.parentPath,
    required this.attachment,
  });

  final AppState state;
  final String parentPath;
  final MessageAttachment attachment;

  @override
  State<_ProtectedImagePreview> createState() => _ProtectedImagePreviewState();
}

class _ProtectedImagePreviewState extends State<_ProtectedImagePreview> {
  late Future<Uint8List?> _image;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _image = _load();
  }

  Future<Uint8List?> _load() async {
    try {
      _loadError = null;
      return await widget.state.api.messageAttachmentBytes(
        widget.parentPath,
        widget.attachment.id,
        preview: true,
      );
    } catch (error) {
      _loadError = error;
      return null;
    }
  }

  void _retry() {
    setState(() {
      _image = _load();
    });
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    namesRoute: true,
    label: 'Просмотр изображения ${widget.attachment.originalName}',
    child: Dialog(
      backgroundColor: const Color(0xFF17191D),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.attachment.originalName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть просмотр изображения',
                    autofocus: true,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FutureBuilder<Uint8List?>(
                  future: _image,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 5,
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          semanticLabel: widget.attachment.originalName,
                          errorBuilder: (_, _, _) =>
                              _PreviewUnavailable(onRetry: _retry),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.done) {
                      final unavailable =
                          _loadError is ApiFailure &&
                          ((_loadError! as ApiFailure).status == 404 ||
                              (_loadError! as ApiFailure).status == 410);
                      return _PreviewUnavailable(
                        deleted: unavailable,
                        onRetry: unavailable ? null : _retry,
                      );
                    }
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Загружаем изображение…'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({this.deleted = false, this.onRetry});

  final bool deleted;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, size: 42),
        const SizedBox(height: 10),
        Text(
          deleted
              ? 'Вложение удалено или недоступно.'
              : 'Не удалось загрузить изображение.',
          textAlign: TextAlign.center,
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Повторить'),
          ),
        ],
      ],
    ),
  );
}
