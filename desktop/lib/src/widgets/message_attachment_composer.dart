import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class MessageAttachmentComposer extends StatefulWidget {
  const MessageAttachmentComposer({
    super.key,
    required this.state,
    required this.attachments,
    required this.onChanged,
    required this.onPending,
    this.directMessageId,
  });

  final AppState state;
  final List<MessageAttachment> attachments;
  final ValueChanged<List<MessageAttachment>> onChanged;
  final ValueChanged<bool> onPending;
  final String? directMessageId;

  @override
  State<MessageAttachmentComposer> createState() =>
      _MessageAttachmentComposerState();
}

class _MessageAttachmentComposerState extends State<MessageAttachmentComposer> {
  bool _pending = false;
  String? _error;

  Future<void> _pick() async {
    if (_pending) return;
    final remaining = 10 - widget.attachments.length;
    if (remaining <= 0) {
      setState(
        () => _error = 'К сообщению можно прикрепить не более 10 файлов.',
      );
      return;
    }
    final files = await openFiles(
      acceptedTypeGroups: const [XTypeGroup(label: 'Любые файлы')],
    );
    if (files.isEmpty || !mounted) return;
    if (files.length > remaining) {
      setState(
        () => _error = 'К сообщению можно прикрепить не более 10 файлов.',
      );
      return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    widget.onPending(true);
    final selected = [...widget.attachments];
    try {
      for (final file in files) {
        final size = await file.length();
        if (size > 25000000) {
          throw const FormatException(
            'Каждый файл должен быть не больше 25 МБ.',
          );
        }
        final uploaded = await widget.state.uploadAttachment(
          file.name,
          await file.readAsBytes(),
          directMessageId: widget.directMessageId,
        );
        if (!mounted) return;
        selected.add(uploaded);
        widget.onChanged(List.unmodifiable(selected));
      }
    } catch (cause) {
      if (mounted) {
        setState(() {
          _error = cause is FormatException ? cause.message : 'Не удалось загрузить файл. Проверьте соединение и попробуйте снова.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _pending = false);
        widget.onPending(false);
      }
    }
  }

  String _sizeLabel(int bytes) {
    if (bytes < 1000) return '$bytes Б';
    if (bytes < 1000000) return '${(bytes / 1000).toStringAsFixed(1)} КБ';
    return '${(bytes / 1000000).toStringAsFixed(1)} МБ';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton.icon(
            onPressed: _pending || widget.state.sending ? null : _pick,
            icon: const Icon(Icons.attach_file, size: 18),
            label: const Text('Прикрепить файлы'),
          ),
          const Text(
            'До 10 файлов · 25 МБ каждый',
            style: TextStyle(color: Color(0xFF9AA0AA), fontSize: 11),
          ),
          if (_pending) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const Text('Загружаем…', style: TextStyle(fontSize: 12)),
          ],
        ],
      ),
      if (_error case final error?)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: const TextStyle(color: Color(0xFFFF7777), fontSize: 12),
            ),
          ),
        ),
      if (widget.attachments.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final attachment in widget.attachments)
              InputChip(
                avatar: const Icon(Icons.insert_drive_file_outlined, size: 17),
                label: Text(
                  '${attachment.originalName} · ${_sizeLabel(attachment.sizeBytes)}',
                  overflow: TextOverflow.ellipsis,
                ),
                onDeleted: _pending || widget.state.sending
                    ? null
                    : () => widget.onChanged(
                        widget.attachments
                            .where((item) => item.id != attachment.id)
                            .toList(growable: false),
                      ),
              ),
          ],
        ),
    ],
  );
}
