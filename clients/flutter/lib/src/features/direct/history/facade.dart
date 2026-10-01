import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin DirectHistoryFacade on ApiFacadeBase {
  late final _directHistory = DirectHistoryApi(transport);

  Future<List<DirectChatMessage>> directMessageHistory(String id) async {
    return (await directMessageHistoryPage(id)).messages;
  }

  Future<DirectChatMessagePage> directMessageHistoryPage(
    String id, {
    String? before,
    String? at,
  }) => _directHistory.directMessageHistoryPage(id, before: before, at: at);
}
