import '../../../models.dart';
import '../lifecycle/controller.dart';

extension WorkspaceDirects on WorkspaceController {
  Future<void> refreshDirectMessages() async {
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    try {
      final result = await api.directMessages();
      if (!accepts(ticket)) return;
      directMessages = result;
      if (navigationSection == NavigationSection.directMessages) {
        final candidates = await api.directMessageCandidates();
        if (!accepts(ticket)) return;
        directMessageCandidates = candidates;
      }
    } catch (cause) {
      if (accepts(ticket)) effects.error(effects.message(cause));
    }
    if (accepts(ticket)) changed();
  }

  Future<void> createDirectConversation(DirectCandidate candidate) async {
    final ticket = scope.capture();
    if (!accepts(ticket)) return;
    try {
      final id = await api.openDirectMessage(candidate.id);
      if (!accepts(ticket)) return;
      await refreshDirectMessages();
      if (!accepts(ticket)) return;
      final conversation = directMessages
          .where((value) => value.id == id)
          .firstOrNull;
      if (conversation != null) await openDirectConversation(conversation);
    } catch (cause) {
      if (accepts(ticket)) {
        effects.error(effects.message(cause));
        changed();
      }
    }
  }
}
