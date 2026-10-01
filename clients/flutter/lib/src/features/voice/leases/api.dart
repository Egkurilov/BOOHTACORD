import 'dart:convert';

import '../../../models.dart';
import '../../../core/http/transport.dart';

class VoiceLeasesApi {
  VoiceLeasesApi(this.transport);
  final ApiTransport transport;

  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) async {
    final leaseData = await transport.checked(
      await transport.client.post(
        transport.uri('/voice/channels/$channelId/leases'),
        headers: await transport.headers(jsonBody: true),
        body: jsonEncode({'transfer': transfer}),
      ),
    ) as Map<String, dynamic>;
    final leaseId = leaseData['id'] as String;
    final credential = await transport.checked(
      await transport.client.post(
        transport.uri('/voice/leases/$leaseId/credential'),
        headers: await transport.headers(),
      ),
    ) as Map<String, dynamic>;
    return (
      leaseId,
      VoiceCredential(
        url: credential['url'] as String,
        token: credential['token'] as String,
      ),
    );
  }

  Future<void> releaseVoice(String leaseId) async {
    await transport.checked(
      await transport.client.delete(
        transport.uri('/voice/leases/$leaseId'),
        headers: await transport.headers(),
      ),
    );
  }
}
