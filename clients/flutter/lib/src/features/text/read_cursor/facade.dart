import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin TextReadCursorFacade on ApiFacadeBase {
  late final _textReadCursor = TextReadCursorApi(transport);

  Future<void> advanceTextChannelReadCursor(
    String channelId,
    String messageId,
  ) => _textReadCursor.advanceTextChannelReadCursor(channelId, messageId);
}
