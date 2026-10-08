import 'controller.dart';
import 'entry.dart';

extension QuickJumpOpen on QuickJumpController {
  Future<bool> open(QuickJumpEntry entry) async {
    if (!admitted || opening) return false;
    opening = true;
    error = null;
    final expected = generation;
    changed();
    bool current() => admitted && expected == generation;
    try {
      if (entry.channel != null) {
        final topology = await api.topology();
        if (!current()) return false;
        final target = topology.categories
            .expand((c) => c.channels)
            .where((c) => c.id == entry.targetId)
            .firstOrNull;
        if (target == null) throw StateError('Target no longer authorized');
        effects.acceptTopology(topology);
        await effects.openChannel(target);
      } else {
        final id =
            entry.direct?.id ?? await api.openDirectMessage(entry.targetId);
        if (!current()) return false;
        final directs = await api.directMessages();
        if (!current()) return false;
        final target = directs
            .where((d) => d.id == id && d.participantId == entry.targetId)
            .firstOrNull;
        if (target == null) throw StateError('Target no longer authorized');
        effects.acceptDirects(directs);
        await effects.openDirect(target);
      }
      return true;
    } catch (_) {
      if (current()) error = 'Не удалось открыть выбранный канал или диалог.';
      return false;
    } finally {
      if (current()) {
        opening = false;
        changed();
      }
    }
  }
}
