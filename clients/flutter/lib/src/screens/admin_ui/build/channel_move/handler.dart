import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminChannelMoveAction on AdminScreenStateContext {
  List<Widget> renderAdminChannelMove(
    List<ChannelCategory> categories,
    ChannelCategory? moveSourceCategory,
  ) => [
    if (categories.isNotEmpty) ...[
      const Divider(height: 32),
      DropdownButtonFormField<String>(
        key: ValueKey('move-channel:$adminMoveChannelId'),
        initialValue:
            categories
                .expand((category) => category.channels)
                .any((channel) => channel.id == adminMoveChannelId)
            ? adminMoveChannelId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Перенести канал'),
        items: [
          for (final category in categories)
            for (final channel in category.channels)
              DropdownMenuItem(
                value: channel.id,
                child: Text('${category.name} · ${channel.name}'),
              ),
        ],
        onChanged: adminBusy
            ? null
            : (value) => adminMutateView(() {
                adminMoveChannelId = value;
                adminMoveTargetCategoryId = null;
              }),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('move-target:$adminMoveTargetCategoryId'),
        initialValue:
            categories.any((item) => item.id == adminMoveTargetCategoryId)
            ? adminMoveTargetCategoryId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'В категорию'),
        items: [
          for (final category in categories)
            DropdownMenuItem(value: category.id, child: Text(category.name)),
        ],
        onChanged: adminBusy
            ? null
            : (value) =>
                  adminMutateView(() => adminMoveTargetCategoryId = value),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed:
              adminBusy ||
                  adminMoveChannelId == null ||
                  adminMoveTargetCategoryId == null ||
                  moveSourceCategory?.id == adminMoveTargetCategoryId
              ? null
              : adminMoveChannel,
          child: const Text('Перенести канал'),
        ),
      ),
    ],
  ];
}
