import '../../../models.dart';
import '../lifecycle/controller.dart';

extension WorkspaceSearchTarget on WorkspaceController {
  Future<bool> resolveSearchTarget(
    SearchMessage target,
    bool Function() active,
  ) async {
    if (target.kind == SearchMessageKind.channel) {
      final channel = topology?.categories
          .expand((category) => category.channels)
          .where(
            (value) =>
                value.id == target.conversationId &&
                value.kind == ChannelKind.text,
          )
          .firstOrNull;
      var resolvedChannel = channel;
      if (resolvedChannel == null) {
        await refreshTopology();
        if (!active()) return false;
        resolvedChannel = topology?.categories
            .expand((category) => category.channels)
            .where(
              (value) =>
                  value.id == target.conversationId &&
                  value.kind == ChannelKind.text,
            )
            .firstOrNull;
      }
      if (resolvedChannel == null) {
        searchContextError = 'Найденный канал больше недоступен.';
        loadingSearchContext = false;
        changed();
        return false;
      }
      effects.invalidateText();
      selectedChannel = resolvedChannel;
      selectedDirectMessage = null;
      navigationSection = NavigationSection.channels;
    } else {
      var conversation = directMessages
          .where((value) => value.id == target.conversationId)
          .firstOrNull;
      if (conversation == null) {
        await refreshDirectMessages();
        if (!active()) return false;
        conversation = directMessages
            .where((value) => value.id == target.conversationId)
            .firstOrNull;
      }
      if (conversation == null) {
        searchContextError = 'Личный диалог больше недоступен.';
        loadingSearchContext = false;
        changed();
        return false;
      }
      effects.invalidateText();
      selectedDirectMessage = conversation;
      selectedChannel = null;
      navigationSection = NavigationSection.directMessages;
    }
    return active();
  }
}
