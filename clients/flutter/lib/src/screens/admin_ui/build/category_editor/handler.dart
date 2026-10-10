import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminCategoryEditorAction on AdminScreenStateContext {
  List<Widget> renderAdminCategoryEditor(
    ChannelCategory selectedCategory,
    List<ChannelCategory> categories,
  ) => [
    TextField(
      controller: adminCategoryRename,
      enabled: !adminBusy,
      maxLength: 80,
      decoration: const InputDecoration(labelText: 'Новое название раздела'),
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: adminBusy
              ? null
              : () => adminRenameCategory(selectedCategory),
          child: const Text('Переименовать раздел'),
        ),
        OutlinedButton(
          onPressed: adminBusy || selectedCategory.channels.isNotEmpty
              ? null
              : () => adminDeleteCategory(selectedCategory),
          child: const Text('Удалить пустой раздел'),
        ),
      ],
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: adminBusy || categories.indexOf(selectedCategory) == 0
              ? null
              : () => adminReorderCategory(-1),
          child: const Text('Раздел выше'),
        ),
        OutlinedButton(
          onPressed:
              adminBusy ||
                  categories.indexOf(selectedCategory) == categories.length - 1
              ? null
              : () => adminReorderCategory(1),
          child: const Text('Раздел ниже'),
        ),
      ],
    ),
    const Divider(height: 32),
  ];
}
