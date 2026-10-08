import '../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension RenderAdminVoiceAdmissionAction on AdminScreenStateContext {
  List<Widget> renderAdminVoiceAdmission(
    List<GuildChannel> voiceChannels,
    List<GuildChannel> allChannels,
  ) => [
    if (voiceChannels.any((channel) => !channel.admissionClosed)) ...[
      DropdownButtonFormField<String>(
        key: ValueKey('close-channel:$adminCloseVoiceChannelId'),
        initialValue:
            voiceChannels.any(
              (channel) => channel.id == adminCloseVoiceChannelId,
            )
            ? adminCloseVoiceChannelId
            : null,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Голосовой канал для закрытия',
        ),
        items: [
          for (final channel in voiceChannels)
            DropdownMenuItem(
              value: channel.id,
              child: Text(
                '${channel.name}${channel.admissionClosed ? ' · вход закрыт' : ''}',
              ),
            ),
        ],
        onChanged: adminBusy
            ? null
            : (value) =>
                  adminMutateView(() => adminCloseVoiceChannelId = value),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed:
              adminBusy ||
                  adminCloseVoiceChannelId == null ||
                  voiceChannels.any(
                    (channel) =>
                        channel.id == adminCloseVoiceChannelId &&
                        channel.admissionClosed,
                  )
              ? null
              : () => adminCloseVoiceAdmission(allChannels),
          child: const Text('Закрыть вход'),
        ),
      ),
    ],
  ];
}
