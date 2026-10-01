import '../../conversation/lifecycle/controller.dart';

extension ConversationAcknowledgeMessageIds on ConversationController {
  void acknowledgeMessageIds(Iterable<String?> ids) {
    final acknowledged = ids.whereType<String>().toSet();
    if (acknowledged.isEmpty) return;
    sendRetryIds.removeWhere((_, id) => acknowledged.contains(id));
    for (final id in acknowledged) {
      pendingTextSends.remove(id);
      pendingDirectSends.remove(id);
    }
  }
}
