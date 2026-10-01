import 'dart:convert';

import '../../../core/http/api_failure.dart';
import '../../../core/http/transport.dart';
import 'result.dart';

class VoiceAdmissionApi {
  VoiceAdmissionApi(this.transport);
  final ApiTransport transport;

  Future<VoiceAdmissionCloseResult> closeVoiceAdmission({
    required String channelId,
    required int expectedRevision,
  }) async {
    if (channelId.isEmpty || expectedRevision < 1) {
      throw const ApiFailure(
        'Обновите список голосовых каналов и повторите действие.',
      );
    }
    final data = await transport.checked(
      await transport.client.post(
        transport.uri(
          '/admin/voice-channels/${Uri.encodeComponent(channelId)}/close-admission',
        ),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'expected_revision': expectedRevision}),
      ),
    ) as Map<String, dynamic>;
    final returnedId = data['id'];
    final revision = data['revision'];
    final revokedLeases = data['revoked_leases'];
    if (returnedId != channelId ||
        revision is! int ||
        revision < 1 ||
        revokedLeases is! int ||
        revokedLeases < 0) {
      throw const ApiFailure(
        'Сервер вернул некорректное состояние закрытия канала.',
      );
    }
    return VoiceAdmissionCloseResult(
      channelId: channelId,
      revision: revision,
      revokedLeases: revokedLeases,
    );
  }
}
