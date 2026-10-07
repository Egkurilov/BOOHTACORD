import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'actions.dart';
import 'danger_zone.dart';

class TopologyChannelInspector extends StatefulWidget {
  const TopologyChannelInspector({super.key, required this.category, required this.channel, required this.categories, required this.revision, required this.busy, required this.actions});
  final ChannelCategory category;
  final GuildChannel channel;
  final List<ChannelCategory> categories;
  final int revision;
  final bool busy;
  final TopologyActions actions;
  @override
  State<TopologyChannelInspector> createState() => _TopologyChannelInspectorState();
}

class _TopologyChannelInspectorState extends State<TopologyChannelInspector> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _targetCategoryId;
  List<ChannelCategory> get _targets => widget.categories.where((item) => item.id != widget.category.id).toList(growable: false);
  @override
  void initState() { super.initState(); _sync(); }
  void _sync() {
    _name.text = widget.channel.name;
    _description.text = widget.channel.description ?? '';
    _targetCategoryId = _targets.firstOrNull?.id;
  }
  @override
  void didUpdateWidget(covariant TopologyChannelInspector old) {
    super.didUpdateWidget(old);
    if (old.channel.id != widget.channel.id) { _sync(); return; }
    if (old.channel.name != widget.channel.name && _name.text == old.channel.name) _name.text = widget.channel.name;
    if (old.channel.description != widget.channel.description && _description.text == (old.channel.description ?? '')) _description.text = widget.channel.description ?? '';
    if (!_targets.any((item) => item.id == _targetCategoryId)) _targetCategoryId = _targets.firstOrNull?.id;
  }
  @override
  void dispose() { _name.dispose(); _description.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final index = widget.category.channels.indexWhere((item) => item.id == widget.channel.id);
    final voice = widget.channel.kind == ChannelKind.voice;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(voice ? 'ГОЛОСОВОЙ КАНАЛ' : 'ТЕКСТОВЫЙ КАНАЛ', style: const TextStyle(fontSize: 12, letterSpacing: 1.1)),
      Text(widget.channel.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
      Text('Раздел: ${widget.category.name} · Порядок: ${index + 1}', maxLines: 1, overflow: TextOverflow.ellipsis),
      if (voice) Semantics(liveRegion: true, child: Row(children: [Icon(widget.channel.admissionClosed ? Icons.lock_outline : Icons.check_circle_outline, size: 18), const SizedBox(width: 6), Text(widget.channel.admissionClosed ? 'Вход закрыт' : 'Вход открыт')])),
      const SizedBox(height: 16),
      TextField(key: const ValueKey('admin-topology-channel-name'), controller: _name, enabled: !widget.busy, maxLength: 80, decoration: const InputDecoration(labelText: 'Новое имя канала')),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: widget.busy ? null : () => widget.actions.renameChannel(widget.channel, widget.revision, _name.text.trim()), child: const Text('Переименовать канал'))),
      if (!voice) ...[
        TextField(key: const ValueKey('admin-topology-channel-description'), controller: _description, enabled: !widget.busy, maxLength: 200, maxLines: 3, decoration: const InputDecoration(labelText: 'Описание канала')),
        Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: widget.busy ? null : () => widget.actions.saveDescription(widget.channel, widget.revision, _description.text), child: const Text('Сохранить описание'))),
      ],
      if (_targets.isEmpty) const Text('Создайте другой раздел, чтобы переместить канал.'),
      if (_targets.isNotEmpty) DropdownButtonFormField<String>(key: ValueKey('topology-move:${widget.channel.id}:$_targetCategoryId'), initialValue: _targetCategoryId, decoration: const InputDecoration(labelText: 'Переместить в раздел'), items: [for (final item in _targets) DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))], onChanged: widget.busy ? null : (value) => setState(() => _targetCategoryId = value)),
      if (_targets.isNotEmpty) Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: widget.busy || _targetCategoryId == null ? null : () => widget.actions.moveChannel(widget.channel, widget.revision, _targetCategoryId!), child: const Text('Переместить канал'))),
      Wrap(spacing: 8, children: [
        OutlinedButton(key: const ValueKey('admin-topology-channel-up'), onPressed: widget.busy || index <= 0 ? null : () => widget.actions.reorderChannel(widget.category.id, widget.channel, widget.revision, -1), child: const Text('Канал выше')),
        OutlinedButton(key: const ValueKey('admin-topology-channel-down'), onPressed: widget.busy || index < 0 || index >= widget.category.channels.length - 1 ? null : () => widget.actions.reorderChannel(widget.category.id, widget.channel, widget.revision, 1), child: const Text('Канал ниже')),
      ]),
      TopologyDangerZone(description: voice ? 'Закрытие остановит новый вход и запустит отзыв доступа в SFU.' : 'Архивация скрывает канал из навигации, история сообщений сохраняется.', action: voice ? OutlinedButton(onPressed: widget.busy || widget.channel.admissionClosed ? null : () => widget.actions.closeVoiceAdmission(widget.channel, widget.revision), style: OutlinedButton.styleFrom(foregroundColor: GcColors.danger), child: const Text('Закрыть вход')) : OutlinedButton(onPressed: widget.busy ? null : () => widget.actions.archiveTextChannel(widget.channel, widget.revision), style: OutlinedButton.styleFrom(foregroundColor: GcColors.danger), child: const Text('Архивировать канал'))),
    ]);
  }
}
