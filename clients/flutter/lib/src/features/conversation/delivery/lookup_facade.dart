import '../../../core/http/facade_base.dart';
import '../../../models.dart';
import 'lookup_api.dart';

mixin DeliveryLookupFacade on ApiFacadeBase {
  late final _delivery = DeliveryLookupApi(transport);
  Future<ChatMessage?> findSentText(
    String conversation,
    String client,
    String owner,
  ) => transport.run(() => _delivery.text(conversation, client, owner));
  Future<DirectChatMessage?> findSentDirect(
    String conversation,
    String client,
    String owner,
  ) => transport.run(() => _delivery.direct(conversation, client, owner));
}
