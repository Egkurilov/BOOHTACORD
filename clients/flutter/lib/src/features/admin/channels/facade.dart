import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminChannelsFacade on ApiFacadeBase {
  late final _adminChannels = AdminChannelsApi(transport);

  Future<void> createChannel({
    required String categoryId,
    required String name,
    required ChannelKind kind,
  }) => transport.run(
    () => _adminChannels.createChannel(
      categoryId: categoryId,
      name: name,
      kind: kind,
    ),
  );

  Future<void> renameChannel({
    required String channelId,
    required String name,
    required int expectedRevision,
  }) => transport.run(
    () => _adminChannels.renameChannel(
      channelId: channelId,
      name: name,
      expectedRevision: expectedRevision,
    ),
  );

  Future<void> updateChannelDescription({
    required String channelId,
    required String description,
    required int expectedRevision,
  }) => transport.run(
    () => _adminChannels.updateDescription(
      channelId: channelId,
      description: description,
      expectedRevision: expectedRevision,
    ),
  );

  Future<void> archiveTextChannel({
    required String channelId,
    required int expectedRevision,
  }) => transport.run(
    () => _adminChannels.archiveTextChannel(
      channelId: channelId,
      expectedRevision: expectedRevision,
    ),
  );
}
