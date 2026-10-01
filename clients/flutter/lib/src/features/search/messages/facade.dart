import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin SearchMessagesFacade on ApiFacadeBase {
  late final _searchMessages = SearchMessagesApi(transport);

  Future<SearchMessagePage> searchMessages(
    String query, {
    String? channelId,
    String? directMessageId,
    String? before,
    int limit = 20,
  }) => transport.run(
    () => _searchMessages.searchMessages(
      query,
      channelId: channelId,
      directMessageId: directMessageId,
      before: before,
      limit: limit,
    ),
  );
}
