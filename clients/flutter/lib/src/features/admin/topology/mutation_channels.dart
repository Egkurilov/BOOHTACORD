part of 'mutation_controller.dart';

mixin _TopologyChannels on _AdminTopologyMutationBase {
  Future<void> renameChannel(
    GuildChannel channel,
    int revision,
    String name,
  ) async {
    if (!await validateRevision(revision)) return;
    final current = currentChannel(channel.id);
    if (current == null) return recoverStaleTopology();
    await mutate(
      'Канал переименован. Топология обновлена.',
      () => api.renameChannel(
        channelId: current.id,
        name: name,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> saveChannelDescription(
    GuildChannel channel,
    int revision,
    String description,
  ) async {
    if (!await validateRevision(revision)) return;
    final current = currentChannel(channel.id);
    if (current == null) return recoverStaleTopology();
    await mutate(
      'Описание канала сохранено. Топология обновлена.',
      () => api.updateChannelDescription(
        channelId: current.id,
        description: description,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> moveChannel(
    GuildChannel channel,
    int revision,
    String targetId,
  ) async {
    if (!await validateRevision(revision)) return;
    final topology = this.topology;
    final current = currentChannel(channel.id);
    final target = currentCategory(targetId);
    if (topology == null || current == null || target == null) {
      return recoverStaleTopology();
    }
    final source = topology.categories
        .where(
          (category) => category.channels.any((item) => item.id == current.id),
        )
        .firstOrNull;
    if (source == null || source.id == target.id) return;
    await mutate(
      'Канал перенесён. Топология обновлена.',
      () => api.moveChannel(
        channelId: current.id,
        categoryId: target.id,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> reorderChannel(
    String categoryId,
    GuildChannel channel,
    int revision,
    int direction,
  ) async {
    if (!await validateRevision(revision)) return;
    final topology = this.topology;
    final category = currentCategory(categoryId);
    if (topology == null || category == null) return recoverStaleTopology();
    final index = category.channels.indexWhere((item) => item.id == channel.id);
    final target = index + direction;
    if (index < 0 || target < 0 || target >= category.channels.length) return;
    final ids = category.channels.map((item) => item.id).toList();
    final moved = ids[index];
    ids[index] = ids[target];
    ids[target] = moved;
    await mutate(
      'Порядок каналов сохранён. Топология обновлена.',
      () => api.reorderChannels(
        categoryId: category.id,
        channelIds: ids,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }
}
