import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminChannelArchiveAction on AdminScreenStateContext {
  List<Widget> renderAdminChannelArchive(
    List<GuildChannel> textChannels,
    List<GuildChannel> allChannels,
  ) => [
    if (textChannels.isNotEmpty) ...[
      const Divider(height: 32),
      DropdownButtonFormField<String>(
        key: ValueKey('archive-channel:$adminArchiveChannelId'),
        initialValue:
            textChannels.any((channel) => channel.id == adminArchiveChannelId)
            ? adminArchiveChannelId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Текстовый канал для архивации',
        ),
        items: [
          for (final channel in textChannels)
            DropdownMenuItem(value: channel.id, child: Text(channel.name)),
        ],
        onChanged: adminBusy
            ? null
            : (value) => adminMutateView(() => adminArchiveChannelId = value),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: adminBusy || adminArchiveChannelId == null
              ? null
              : () => adminArchiveTextChannel(allChannels),
          child: const Text('Архивировать канал'),
        ),
      ),
    ],
  ];
}
