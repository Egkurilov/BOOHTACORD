import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin DirectConversationsFacade on ApiFacadeBase {
  late final _directConversations = DirectConversationsApi(transport);

  Future<List<DirectConversation>> directMessages() =>
      transport.run(() => _directConversations.directMessages());

  Future<List<DirectCandidate>> directMessageCandidates() =>
      transport.run(() => _directConversations.directMessageCandidates());

  Future<String> openDirectMessage(String participantId) => transport.run(
    () => _directConversations.openDirectMessage(participantId),
  );
}
