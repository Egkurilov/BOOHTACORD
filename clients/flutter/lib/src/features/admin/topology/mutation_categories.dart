part of 'mutation_controller.dart';

mixin _TopologyCategories on _AdminTopologyMutationBase {
  Future<void> renameCategory(
    ChannelCategory category,
    int revision,
    String name,
  ) async {
    if (!await validateRevision(revision)) return;
    final current = currentCategory(category.id);
    if (current == null) return recoverStaleTopology();
    await mutate(
      'Категория переименована. Топология обновлена.',
      () => api.renameCategory(
        categoryId: current.id,
        name: name,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> deleteCategory(ChannelCategory category, int revision) async {
    if (!await validateRevision(revision)) return;
    final current = currentCategory(category.id);
    if (current == null) return recoverStaleTopology();
    if (current.channels.isNotEmpty) return;
    final approved = await confirm(
      TopologyConfirmation(
        title: 'Удалить категорию?',
        content: 'Удалить пустую категорию «${current.name}»?',
        confirmLabel: 'Удалить',
      ),
    );
    if (approved != true || !await validateRevision(revision)) return;
    final latest = currentCategory(category.id);
    if (latest == null) return recoverStaleTopology();
    if (latest.channels.isNotEmpty) return;
    await mutate(
      'Пустая категория удалена. Топология обновлена.',
      () => api.deleteEmptyCategory(
        categoryId: latest.id,
        expectedRevision: revision,
      ),
      revisionBound: true,
    );
  }

  Future<void> reorderCategory(
    String categoryId,
    int revision,
    int direction,
  ) async {
    if (!await validateRevision(revision)) return;
    final topology = this.topology;
    if (topology == null) return recoverStaleTopology();
    final index = topology.categories.indexWhere(
      (item) => item.id == categoryId,
    );
    final target = index + direction;
    if (index < 0 || target < 0 || target >= topology.categories.length) return;
    final ids = topology.categories.map((item) => item.id).toList();
    final moved = ids[index];
    ids[index] = ids[target];
    ids[target] = moved;
    await mutate(
      'Порядок категорий сохранён. Топология обновлена.',
      () => api.reorderCategories(categoryIds: ids, expectedRevision: revision),
      revisionBound: true,
    );
  }
}
