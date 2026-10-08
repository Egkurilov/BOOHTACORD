import 'controller.dart';

extension QuickJumpLoad on QuickJumpController {
  Future<void> load() async {
    if (!canLoad) return;
    final expected = generation;
    final cursor = nextAfter;
    loading = true;
    error = null;
    changed();
    try {
      final page = await api.directMessageCandidatePage(after: cursor);
      if (!admitted || expected != generation) return;
      final ids = people.map((p) => p.id).toSet();
      for (final p in page.items) {
        if (ids.add(p.id)) people.add(p);
      }
      if (cursor != null) visited.add(cursor);
      nextAfter = page.nextAfter;
      if (nextAfter != null && visited.contains(nextAfter)) nextAfter = null;
      loaded = true;
    } catch (_) {
      if (admitted && expected == generation) {
        error = 'Не удалось загрузить людей. Повторите попытку.';
      }
    } finally {
      if (admitted && expected == generation) {
        loading = false;
        changed();
      }
    }
  }
}
