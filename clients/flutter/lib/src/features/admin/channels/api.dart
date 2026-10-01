import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import '../topology_validation/validate.dart';

class AdminChannelsApi {
  AdminChannelsApi(this.transport);
  final ApiTransport transport;

  Future<void> createChannel({
    required String categoryId,
    required String name,
    required ChannelKind kind,
  }) async {
    final normalized = name.trim();
    if (categoryId.isEmpty ||
        normalized.isEmpty ||
        normalized.runes.length > 80) {
      throw const ApiFailure('Введите имя канала до 80 символов.');
    }
    await transport.checked(
      await transport.client.post(
        transport.uri(
          '/admin/categories/${Uri.encodeComponent(categoryId)}/channels',
        ),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'name': name,
          'kind': kind == ChannelKind.text ? 'TEXT' : 'VOICE',
        }),
      ),
    );
  }

  Future<void> renameChannel({
    required String channelId,
    required String name,
    required int expectedRevision,
  }) async {
    validateAdminName(name, 'канала');
    if (channelId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список каналов и повторите действие.');
    }
    await transport.checked(
      await transport.client.patch(
        transport.uri('/admin/channels/${Uri.encodeComponent(channelId)}'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'name': name, 'expected_revision': expectedRevision}),
      ),
    );
  }

  Future<void> archiveTextChannel({
    required String channelId,
    required int expectedRevision,
  }) async {
    if (channelId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure('Обновите список каналов и повторите архивацию.');
    }
    await transport.checked(
      await transport.client.delete(
        transport.uri('/admin/channels/${Uri.encodeComponent(channelId)}'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({
          'expected_revision': expectedRevision,
          'confirm_archive': true,
        }),
      ),
    );
  }
}
