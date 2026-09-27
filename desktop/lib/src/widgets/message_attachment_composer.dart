import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/api_client.dart';

class MessageAttachmentComposer extends StatefulWidget {
  const MessageAttachmentComposer({
    super.key,
    required this.state,
    required this.attachments,
    required this.onChanged,
    required this.onPending,
    this.channelId,
    this.directMessageId,
    this.filePicker,
  }) : assert((channelId == null) != (directMessageId == null));

  final AppState state;
  final List<MessageAttachment> attachments;
  final ValueChanged<List<MessageAttachment>> onChanged;
  final ValueChanged<bool> onPending;
  final String? channelId;
  final String? directMessageId;
  final Future<List<XFile>> Function()? filePicker;

  @override
  State<MessageAttachmentComposer> createState() =>
      _MessageAttachmentComposerState();
}

class _MessageAttachmentComposerState extends State<MessageAttachmentComposer> {
  bool _pending = false;
  String? _error;
  final List<XFile> _failedFiles = [];
  String? _activeName;
  int? _activePercent;
  int _generation = 0;

  String get _scope => widget.channelId == null
      ? 'dm:${widget.directMessageId}'
      : 'text:${widget.channelId}';

  bool _isCurrent(int generation, String scope) =>
      mounted && _generation == generation && _scope == scope;

  @override
  void didUpdateWidget(covariant MessageAttachmentComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldScope = oldWidget.channelId == null
        ? 'dm:${oldWidget.directMessageId}'
        : 'text:${oldWidget.channelId}';
    if (oldScope != _scope) {
      _generation++;
      _failedFiles.clear();
      _pending = false;
      _error = null;
      _activeName = null;
      _activePercent = null;
      if (oldWidget.onPending != widget.onPending) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onPending(false);
        });
      }
    }
  }

  Future<void> _pick() async {
    if (_pending || widget.state.sending) return;
    final remaining = 10 - widget.attachments.length - _failedFiles.length;
    if (remaining <= 0) {
      setState(
        () => _error = 'К сообщению можно прикрепить не более 10 файлов.',
      );
      return;
    }
    final generation = _generation;
    final scope = _scope;
    List<XFile> files;
    try {
      files =
          await (widget.filePicker?.call() ??
              openFiles(
                acceptedTypeGroups: const [XTypeGroup(label: 'Любые файлы')],
              ));
    } catch (_) {
      if (_isCurrent(generation, scope)) {
        setState(() => _error = 'Не удалось выбрать файлы. Повторите попытку.');
      }
      return;
    }
    if (files.isEmpty || !_isCurrent(generation, scope)) return;
    if (files.length > remaining) {
      setState(
        () => _error = 'К сообщению можно прикрепить не более 10 файлов.',
      );
      return;
    }
    await _uploadBatch(files, generation: generation, scope: scope);
  }

  Future<void> _retry(XFile file) async {
    if (_pending || widget.state.sending || !_failedFiles.contains(file)) {
      return;
    }
    setState(() => _failedFiles.remove(file));
    await _uploadBatch([file], generation: _generation, scope: _scope);
  }

  Future<void> _uploadBatch(
    List<XFile> files, {
    required int generation,
    required String scope,
  }) async {
    if (!_isCurrent(generation, scope) || _pending) return;
    final channelId = widget.channelId;
    final directMessageId = widget.directMessageId;
    setState(() {
      _pending = true;
      _error = null;
    });
    widget.onPending(true);
    final selected = [...widget.attachments];
    try {
      for (final file in files) {
        if (!_isCurrent(generation, scope)) return;
        setState(() {
          _activeName = file.name;
          _activePercent = 0;
        });
        try {
          final size = await file.length();
          if (!_isCurrent(generation, scope)) return;
          if (size > 25000000) {
            throw const FormatException(
              'Каждый файл должен быть не больше 25 МБ.',
            );
          }
          final bytes = await file.readAsBytes();
          if (!_isCurrent(generation, scope)) return;
          if (bytes.length > 25000000) {
            throw const FormatException(
              'Каждый файл должен быть не больше 25 МБ.',
            );
          }
          final uploaded = await widget.state.uploadAttachment(
            file.name,
            bytes,
            channelId: channelId,
            directMessageId: directMessageId,
            onProgress: (sent, total) {
              if (!_isCurrent(generation, scope) || total <= 0) return;
              final percent = (sent * 100 ~/ total).clamp(0, 100);
              if (percent != _activePercent) {
                setState(() => _activePercent = percent);
              }
            },
          );
          if (!_isCurrent(generation, scope)) return;
          selected.add(uploaded);
          widget.onChanged(List.unmodifiable(selected));
        } on FormatException catch (cause) {
          if (!_isCurrent(generation, scope)) return;
          setState(() => _error = cause.message);
        } catch (cause) {
          if (!_isCurrent(generation, scope)) return;
          setState(() {
            _failedFiles.add(file);
            _error = cause is ApiFailure && cause.status == 507
                ? 'На сервере недостаточно места для ${file.name}. Повторите позже.'
                : 'Не удалось загрузить ${file.name}. Проверьте соединение и попробуйте снова.';
          });
        }
      }
    } finally {
      if (_isCurrent(generation, scope)) {
        setState(() {
          _pending = false;
          _activeName = null;
          _activePercent = null;
        });
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
            SizedBox(
              width: 80,
              child: LinearProgressIndicator(
                value: _activePercent == null ? null : _activePercent! / 100,
              ),
            ),
            Text(
              _activeName == null
                  ? 'Загружаем…'
                  : _activePercent == 100
                  ? '${_activeName!} · обрабатываем…'
                  : '${_activeName!} · ${_activePercent ?? 0}%',
              style: const TextStyle(fontSize: 12),
            ),
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
      if (_failedFiles.isNotEmpty)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final file in _failedFiles)
              Tooltip(
                message: 'Повторить загрузку ${file.name}',
                child: InputChip(
                  avatar: const Icon(Icons.error_outline, size: 17),
                  label: Text('${file.name} · не загружено'),
                  onPressed: _pending || widget.state.sending
                      ? null
                      : () => _retry(file),
                  onDeleted: _pending || widget.state.sending
                      ? null
                      : () => setState(() => _failedFiles.remove(file)),
                ),
              ),
          ],
        ),
    ],
  );
}
