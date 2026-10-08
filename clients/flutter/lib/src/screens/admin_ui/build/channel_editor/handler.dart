import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminChannelEditorAction on AdminScreenStateContext {
  List<Widget> renderAdminChannelEditor(
    GuildChannel? selectedChannel,
    List<GuildChannel> channels,
  ) => [
    if (selectedChannel != null) ...[
      TextField(
        controller: adminChannelRename,
        enabled: !adminBusy,
        maxLength: 80,
        decoration: const InputDecoration(labelText: 'Новое имя канала'),
      ),
      TextField(
        controller: adminChannelDescription,
        enabled: !adminBusy,
        maxLength: 200,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Описание канала',
          hintText: 'Кратко объясните назначение канала',
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: adminBusy
              ? null
              : () => adminRenameChannel(selectedChannel),
          child: const Text('Переименовать канал'),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: adminBusy
              ? null
              : () => adminSaveChannelDescription(selectedChannel),
          child: const Text('Сохранить описание'),
        ),
      ),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: adminBusy || channels.indexOf(selectedChannel) == 0
                ? null
                : () => adminReorderChannel(-1),
            child: const Text('Канал выше'),
          ),
          OutlinedButton(
            onPressed:
                adminBusy ||
                    channels.indexOf(selectedChannel) == channels.length - 1
                ? null
                : () => adminReorderChannel(1),
            child: const Text('Канал ниже'),
          ),
        ],
      ),
    ],
  ];
}
