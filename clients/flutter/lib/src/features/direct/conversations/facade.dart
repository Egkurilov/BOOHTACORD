import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin DirectConversationsFacade on ApiFacadeBase {
  late final _directConversations = DirectConversationsApi(transport);

  Future<List<DirectConversation>> directMessages() =>
      _directConversations.directMessages();

  Future<List<DirectCandidate>> directMessageCandidates() =>
      _directConversations.directMessageCandidates();

  Future<String> openDirectMessage(String participantId) =>
      _directConversations.openDirectMessage(participantId);
}
