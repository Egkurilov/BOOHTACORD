part of 'mutation_controller.dart';

mixin _TopologyDangerActions on _AdminTopologyMutationBase {
  Future<void> archiveTextChannel(GuildChannel channel, int revision) async {
    if (!await validateRevision(revision)) return;
    final current = currentChannel(channel.id);
    if (current == null || current.kind != ChannelKind.text) {
      return recoverStaleTopology();
    }
    final approved = await showConfirmationDialog<bool>(
      context: contextProvider(),
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение архивации'),
        content: Text(
          'Архивировать текстовый канал «${current.name}»? История сообщений сохранится, канал исчезнет из навигации.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Архивировать канал'),
          ),
        ],
      ),
    );
    if (approved != true || !await validateRevision(revision)) return;
    final latest = currentChannel(channel.id);
    if (latest == null || latest.kind != ChannelKind.text) {
      return recoverStaleTopology();
    }
    await mutate(
      'Канал архивирован. Топология обновлена.',
      () => api.archiveTextChannel(
        channelId: latest.id,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> closeVoiceAdmission(GuildChannel channel, int revision) async {
    if (!await validateRevision(revision)) return;
    final current = currentChannel(channel.id);
    if (current == null ||
        current.kind != ChannelKind.voice ||
        current.admissionClosed) {
      return;
    }
    final approved = await showConfirmationDialog<bool>(
      context: contextProvider(),
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение закрытия'),
        content: Text(
          'Закрыть вход в голосовой канал «${current.name}»? Участникам будет отправлена причина; отзыв media-доступа в SFU может занять время.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Закрыть вход'),
          ),
        ],
      ),
    );
    if (approved != true || !await validateRevision(revision)) return;
    final latest = currentChannel(channel.id);
    if (latest == null ||
        latest.kind != ChannelKind.voice ||
        latest.admissionClosed) {
      return recoverStaleTopology();
    }
    await mutate(
      'Вход закрыт. Отзыв media-доступа в SFU ещё подтверждается; число отозванных leases не подтверждает отключение участников.',
      () => api.closeVoiceAdmission(
        channelId: latest.id,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }
}
