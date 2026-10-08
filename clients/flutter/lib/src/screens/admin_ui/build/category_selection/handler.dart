import '../category_editor/handler.dart';
import '../channel_selection/handler.dart';
import '../channel_editor/handler.dart';
import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminCategorySelectionAction on AdminScreenStateContext {
  List<Widget> renderAdminCategorySelection(
    String? selectedId,
    List<ChannelCategory> categories,
    ChannelCategory? selectedCategory,
    List<GuildChannel> channels,
    GuildChannel? selectedChannel,
  ) => [
    DropdownButtonFormField<String>(
      key: ValueKey(selectedId),
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Категория'),
      items: [
        for (final category in categories)
          DropdownMenuItem(value: category.id, child: Text(category.name)),
      ],
      onChanged: adminBusy
          ? null
          : (value) => adminMutateView(() {
              adminCategoryId = value;
              final category = categories
                  .where((item) => item.id == value)
                  .firstOrNull;
              adminCategoryRename.text = category?.name ?? '';
              adminChannelId = null;
              adminChannelRename.clear();
              adminChannelDescription.clear();
            }),
    ),
    if (selectedCategory != null) ...[
      ...renderAdminCategoryEditor(selectedCategory, categories),
      ...renderAdminChannelSelection(channels),
      ...renderAdminChannelEditor(selectedChannel, channels),
    ],
    const Divider(height: 32),
    TextField(
      controller: adminChannelName,
      enabled: !adminBusy && categories.isNotEmpty,
      maxLength: 80,
      decoration: const InputDecoration(labelText: 'Новый канал'),
      onSubmitted: (_) => adminCreateChannel(),
    ),
  ];
}
