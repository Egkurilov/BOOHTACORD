part of 'mutation_controller.dart';

mixin _TopologyCreate on _AdminTopologyMutationBase {
  Future<String?> createCategory(String name) async {
    _begin();
    try {
      await api.createCategory(name);
      await refreshTopology();
      if (_disposed) return null;
      final id = currentTopology()?.categories.lastOrNull?.id;
      status = 'Категория создана. Топология обновлена.';
      notifyListeners();
      return id;
    } catch (cause) {
      await recoverTopology(cause);
    } finally {
      _finish();
    }
    return null;
  }

  Future<void> createChannel(
    String categoryId,
    int revision,
    String name,
    ChannelKind kind,
  ) async {
    if (!await validateRevision(revision)) return;
    if (currentCategory(categoryId) == null) {
      await recoverStaleTopology();
      return;
    }
    await mutate('Канал создан. Топология обновлена.', () async {
      await api.createChannel(
        categoryId: categoryId,
        name: name,
        kind: kind,
      );
    });
  }
}
