import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminChannelsFacade on ApiFacadeBase {
  late final _adminChannels = AdminChannelsApi(transport);

  Future<void> createChannel({
    required String categoryId,
    required String name,
    required ChannelKind kind,
  }) => _adminChannels.createChannel(
    categoryId: categoryId,
    name: name,
    kind: kind,
  );

  Future<void> renameChannel({
    required String channelId,
    required String name,
    required int expectedRevision,
  }) => _adminChannels.renameChannel(
    channelId: channelId,
    name: name,
    expectedRevision: expectedRevision,
  );

  Future<void> archiveTextChannel({
    required String channelId,
    required int expectedRevision,
  }) => _adminChannels.archiveTextChannel(
    channelId: channelId,
    expectedRevision: expectedRevision,
  );
}
