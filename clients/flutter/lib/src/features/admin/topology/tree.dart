import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';
import 'create_category_dialog.dart';
import 'tree_rows.dart';

class TopologyTree extends StatelessWidget {
  const TopologyTree({super.key, required this.categories, required this.selectedCategoryId, required this.selectedChannelId, required this.busy, required this.onCreateCategory, required this.onCategoryCreated, required this.onCategorySelected, required this.onChannelSelected});
  final List<ChannelCategory> categories;
  final String? selectedCategoryId, selectedChannelId;
  final bool busy;
  final Future<String?> Function(String) onCreateCategory;
  final ValueChanged<String> onCategoryCreated;
  final ValueChanged<ChannelCategory> onCategorySelected;
  final ValueChanged<GuildChannel> onChannelSelected;

  Future<void> _create(BuildContext context) async {
    if (busy) return;
    final name = await showCreateCategoryDialog(context);
    if (name == null || name.isEmpty) return;
    final id = await onCreateCategory(name);
    if (id != null) onCategoryCreated(id);
  }

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('admin-topology-tree'),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: GcColors.surface, border: Border.all(color: GcColors.border), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('Структура каналов', style: TextStyle(fontWeight: FontWeight.w600))),
        IconButton(tooltip: 'Создать категорию', onPressed: busy ? null : () => _create(context), icon: const Icon(Icons.create_new_folder_outlined)),
      ]),
      if (categories.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Категорий пока нет.')),
      if (categories.isNotEmpty) Expanded(child: ListView(padding: EdgeInsets.zero, children: [
        for (final category in categories) ...[
          TopologyTreeEntry(key: ValueKey('admin-topology-category:${category.id}'), label: category.name, icon: Icons.folder_outlined, selected: selectedCategoryId == category.id && selectedChannelId == null, count: '${category.channels.length}', onSelected: () => onCategorySelected(category)),
          for (final channel in category.channels) TopologyTreeEntry(label: channel.name, icon: topologyChannelIcon(channel.kind), selected: selectedChannelId == channel.id, indent: 18, closed: channel.kind == ChannelKind.voice && channel.admissionClosed, onSelected: () => onChannelSelected(channel), key: ValueKey('admin-topology-channel:${channel.id}')),
        ],
      ])),
    ]),
  );
}
