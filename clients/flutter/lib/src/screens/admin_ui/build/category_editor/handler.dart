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
      decoration: const InputDecoration(labelText: 'Новое имя категории'),
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: adminBusy
              ? null
              : () => adminRenameCategory(selectedCategory),
          child: const Text('Переименовать категорию'),
        ),
        OutlinedButton(
          onPressed: adminBusy || selectedCategory.channels.isNotEmpty
              ? null
              : () => adminDeleteCategory(selectedCategory),
          child: const Text('Удалить пустую категорию'),
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
          child: const Text('Категорию выше'),
        ),
        OutlinedButton(
          onPressed:
              adminBusy ||
                  categories.indexOf(selectedCategory) == categories.length - 1
              ? null
              : () => adminReorderCategory(1),
          child: const Text('Категорию ниже'),
        ),
      ],
    ),
    const Divider(height: 32),
  ];
}
