import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin TextHistoryFacade on ApiFacadeBase {
  late final _textHistory = TextHistoryApi(transport);

  Future<List<ChatMessage>> messages(String channelId) async {
    return (await messagePage(channelId)).messages;
  }

  Future<ChatMessagePage> messagePage(
    String channelId, {
    String? before,
    String? at,
  }) => _textHistory.messagePage(channelId, before: before, at: at);
}
