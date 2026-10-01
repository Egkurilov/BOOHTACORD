import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin DirectReadCursorFacade on ApiFacadeBase {
  late final _directReadCursor = DirectReadCursorApi(transport);

  Future<void> advanceDirectMessageReadCursor(
    String directMessageId,
    String messageId,
  ) => _directReadCursor.advanceDirectMessageReadCursor(
    directMessageId,
    messageId,
  );
}
