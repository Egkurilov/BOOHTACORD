part of 'mutation_controller.dart';

mixin _TopologyDangerActions on _AdminTopologyMutationBase {
  Future<void> archiveTextChannel(GuildChannel channel, int revision) async {
    if (!await validateRevision(revision)) return;
    final current = currentChannel(channel.id);
    if (current == null || current.kind != ChannelKind.text) {
      return recoverStaleTopology();
    }
    final approved = await confirm(
      TopologyConfirmation(
        title: 'Подтверждение архивации',
        content:
            'Архивировать текстовый канал «${current.name}»? История сообщений сохранится, канал исчезнет из навигации.',
        confirmLabel: 'Архивировать канал',
        stillCurrent: () {
          final latest = currentChannel(channel.id);
          return topology?.revision == revision &&
              latest != null &&
              latest.name == current.name &&
              latest.kind == ChannelKind.text;
        },
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
    final approved = await confirm(
      TopologyConfirmation(
        title: 'Подтверждение закрытия',
        content:
            'Закрыть вход в голосовой канал «${current.name}»? Участникам будет отправлена причина; отзыв media-доступа в SFU может занять время.',
        confirmLabel: 'Закрыть вход',
        stillCurrent: () {
          final latest = currentChannel(channel.id);
          return topology?.revision == revision &&
              latest != null &&
              latest.name == current.name &&
              latest.kind == ChannelKind.voice &&
              !latest.admissionClosed;
        },
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
