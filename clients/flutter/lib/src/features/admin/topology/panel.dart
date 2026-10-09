import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';

/// Master tree used by the admin topology editor. Mutations stay in the
/// screen/controller; this widget only owns selection and presentation.
class TopologyTree extends StatelessWidget {
  const TopologyTree({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.selectedChannelId,
    required this.onCategorySelected,
    required this.onChannelSelected,
  });

  final List<ChannelCategory> categories;
  final String? selectedCategoryId;
  final String? selectedChannelId;
  final ValueChanged<ChannelCategory> onCategorySelected;
  final ValueChanged<GuildChannel> onChannelSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Дерево каналов',
    child: Container(
      key: const ValueKey('admin-topology-tree'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: GcColors.surface,
        border: Border.all(color: GcColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: Text(
              'Структура каналов',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final category in categories) ...[
            InkWell(
              key: ValueKey('admin-topology-category:${category.id}'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onCategorySelected(category),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      selectedCategoryId == category.id
                          ? Icons.expand_more
                          : Icons.chevron_right,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${category.channels.length}',
                      style: const TextStyle(color: GcColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            if (selectedCategoryId == category.id)
              for (final channel in category.channels)
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: InkWell(
                    key: ValueKey('admin-topology-channel:${channel.id}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onChannelSelected(channel),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: selectedChannelId == channel.id
                            ? GcColors.selected
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            channel.kind == ChannelKind.text
                                ? Icons.tag
                                : Icons.volume_up_outlined,
                            size: 18,
                            color: GcColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              channel.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (channel.admissionClosed)
                            const Icon(Icons.lock_outline, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
          if (categories.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Разделов пока нет.'),
            ),
        ],
      ),
    ),
  );
}
