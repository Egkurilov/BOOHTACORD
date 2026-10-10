import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminCategoryCreationAction on AdminScreenStateContext {
  List<Widget> renderAdminCategoryCreation(
    List<ChannelCategory> categories,
    String? expandedCategoryId,
    ChannelCategory? selectedCategory,
  ) => [
    TopologyTree(
      categories: categories,
      selectedCategoryId: expandedCategoryId,
      selectedChannelId: adminChannelId,
      onCategorySelected: (category) => adminMutateView(() {
        adminCategoryId = category.id;
        if (!adminCollapsedTopologyCategories.add(category.id)) {
          adminCollapsedTopologyCategories.remove(category.id);
        }
        adminCategoryRename.text = category.name;
        adminChannelId = null;
        adminChannelRename.clear();
        adminChannelDescription.clear();
      }),
      onChannelSelected: (channel) => adminMutateView(() {
        adminCategoryId = selectedCategory?.id;
        if (selectedCategory != null) {
          adminCollapsedTopologyCategories.remove(selectedCategory.id);
        }
        adminChannelId = channel.id;
        adminChannelRename.text = channel.name;
        adminChannelDescription.text = channel.description ?? '';
      }),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: adminCategoryName,
      enabled: !adminBusy,
      maxLength: 80,
      decoration: const InputDecoration(labelText: 'Новый раздел'),
      onSubmitted: (_) => adminCreateCategory(),
    ),
    const SizedBox(height: 8),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonal(
        onPressed: adminBusy ? null : adminCreateCategory,
        child: const Text('Создать раздел'),
      ),
    ),
    const Divider(height: 32),
  ];
}
