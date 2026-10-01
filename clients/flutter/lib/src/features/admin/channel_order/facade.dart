import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin AdminChannelOrderFacade on ApiFacadeBase {
  late final _adminChannelOrder = AdminChannelOrderApi(transport);

  Future<void> reorderCategories({
    required List<String> categoryIds,
    required int expectedRevision,
  }) => _adminChannelOrder.reorderCategories(
    categoryIds: categoryIds,
    expectedRevision: expectedRevision,
  );

  Future<void> reorderChannels({
    required String categoryId,
    required List<String> channelIds,
    required int expectedRevision,
  }) => _adminChannelOrder.reorderChannels(
    categoryId: categoryId,
    channelIds: channelIds,
    expectedRevision: expectedRevision,
  );

  Future<void> moveChannel({
    required String channelId,
    required String categoryId,
    required int expectedRevision,
  }) => _adminChannelOrder.moveChannel(
    channelId: channelId,
    categoryId: categoryId,
    expectedRevision: expectedRevision,
  );
}
