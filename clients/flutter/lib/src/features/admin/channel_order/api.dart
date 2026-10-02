import 'dart:convert';

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import '../topology_validation/validate.dart';

class AdminChannelOrderApi {
  AdminChannelOrderApi(this.transport);
  final ApiTransport transport;

  Future<void> reorderCategories({
    required List<String> categoryIds,
    required int expectedRevision,
  }) async {
    validateOrderedIds(categoryIds, expectedRevision);
    await transport.checked(
      await transport.client.put(
        transport.uri('/admin/categories/order'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'expected_revision': expectedRevision,
          'ids': categoryIds,
        }),
      ),
    );
  }

  Future<void> reorderChannels({
    required String categoryId,
    required List<String> channelIds,
    required int expectedRevision,
  }) async {
    if (categoryId.isEmpty) {
      throw const ApiFailure('Обновите список каналов и повторите действие.');
    }
    validateOrderedIds(channelIds, expectedRevision);
    await transport.checked(
      await transport.client.put(
        transport.uri(
          '/admin/categories/${Uri.encodeComponent(categoryId)}/channels/order',
        ),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'expected_revision': expectedRevision,
          'ids': channelIds,
        }),
      ),
    );
  }

  Future<void> moveChannel({
    required String channelId,
    required String categoryId,
    required int expectedRevision,
  }) async {
    if (channelId.isEmpty || categoryId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список и повторите перенос канала.');
    }
    await transport.checked(
      await transport.client.patch(
        transport.uri(
          '/admin/channels/${Uri.encodeComponent(channelId)}/category',
        ),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'category_id': categoryId,
          'expected_revision': expectedRevision,
        }),
      ),
    );
  }
}
