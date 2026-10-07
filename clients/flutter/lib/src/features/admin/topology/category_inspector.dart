import 'package:flutter/material.dart';

import '../../../models.dart';
import 'actions.dart';
import 'danger_zone.dart';

class TopologyCategoryInspector extends StatefulWidget {
  const TopologyCategoryInspector({super.key, required this.category, required this.categories, required this.revision, required this.busy, required this.actions});
  final ChannelCategory category;
  final List<ChannelCategory> categories;
  final int revision;
  final bool busy;
  final TopologyActions actions;
  @override
  State<TopologyCategoryInspector> createState() => _TopologyCategoryInspectorState();
}

class _TopologyCategoryInspectorState extends State<TopologyCategoryInspector> {
  final _name = TextEditingController();
  final _channelName = TextEditingController();
  ChannelKind _kind = ChannelKind.voice;
  @override
  void initState() { super.initState(); _name.text = widget.category.name; }
  @override
  void didUpdateWidget(covariant TopologyCategoryInspector old) {
    super.didUpdateWidget(old);
    if (old.category.id != widget.category.id || (_name.text == old.category.name && old.category.name != widget.category.name)) _name.text = widget.category.name;
  }
  @override
  void dispose() { _name.dispose(); _channelName.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final index = widget.categories.indexWhere((item) => item.id == widget.category.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('РАЗДЕЛ', style: TextStyle(fontSize: 12, letterSpacing: 1.1)),
      Text(widget.category.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
      Text('Каналов: ${widget.category.channels.length} · Порядок: ${index + 1}'),
      const SizedBox(height: 16),
      TextField(key: const ValueKey('admin-topology-category-name'), controller: _name, enabled: !widget.busy, maxLength: 80, decoration: const InputDecoration(labelText: 'Новое имя категории')),
      Align(alignment: Alignment.centerLeft, child: OutlinedButton(onPressed: widget.busy ? null : () => widget.actions.renameCategory(widget.category, widget.revision, _name.text.trim()), child: const Text('Переименовать категорию'))),
      Wrap(spacing: 8, children: [
        OutlinedButton(key: const ValueKey('admin-topology-category-up'), onPressed: widget.busy || index <= 0 ? null : () => widget.actions.reorderCategory(widget.category.id, widget.revision, -1), child: const Text('Категорию выше')),
        OutlinedButton(key: const ValueKey('admin-topology-category-down'), onPressed: widget.busy || index < 0 || index >= widget.categories.length - 1 ? null : () => widget.actions.reorderCategory(widget.category.id, widget.revision, 1), child: const Text('Категорию ниже')),
      ]),
      const Divider(height: 32),
      Text('Создать канал', style: Theme.of(context).textTheme.titleMedium),
      TextField(key: const ValueKey('admin-topology-new-channel'), controller: _channelName, enabled: !widget.busy, maxLength: 80, decoration: const InputDecoration(labelText: 'Название канала'), onChanged: (_) => setState(() {})),
      SegmentedButton<ChannelKind>(segments: const [ButtonSegment(value: ChannelKind.text, label: Text('Текст')), ButtonSegment(value: ChannelKind.voice, label: Text('Голос'))], selected: {_kind}, onSelectionChanged: widget.busy ? null : (value) => setState(() => _kind = value.single)),
      Align(alignment: Alignment.centerLeft, child: FilledButton.tonal(onPressed: widget.busy || _channelName.text.trim().isEmpty ? null : () => widget.actions.createChannel(widget.category.id, widget.revision, _channelName.text.trim(), _kind), child: const Text('Создать канал'))),
      if (widget.category.channels.isEmpty) TopologyDangerZone(description: 'Категория должна быть пустой перед удалением.', action: OutlinedButton(onPressed: widget.busy ? null : () => widget.actions.deleteCategory(widget.category, widget.revision), child: const Text('Удалить категорию'))),
    ]);
  }
}
