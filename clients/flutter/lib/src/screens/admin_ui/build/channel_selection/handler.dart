import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminChannelSelectionAction on AdminScreenStateContext {
  List<Widget> renderAdminChannelSelection(List<GuildChannel> channels) => [
    DropdownButtonFormField<String>(
      key: ValueKey(adminChannelId),
      initialValue: channels.any((item) => item.id == adminChannelId)
          ? adminChannelId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Канал'),
      items: [
        for (final channel in channels)
          DropdownMenuItem(value: channel.id, child: Text(channel.name)),
      ],
      onChanged: adminBusy
          ? null
          : (value) => adminMutateView(() {
              adminChannelId = value;
              adminChannelRename.text =
                  channels
                      .where((item) => item.id == value)
                      .firstOrNull
                      ?.name ??
                  '';
              adminChannelDescription.text =
                  channels
                      .where((item) => item.id == value)
                      .firstOrNull
                      ?.description ??
                  '';
            }),
    ),
  ];
}
