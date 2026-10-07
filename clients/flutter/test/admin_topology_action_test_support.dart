import 'package:boohtacord_desktop/src/models.dart';
import 'package:boohtacord_desktop/src/services/api_client.dart';

import 'admin_topology_fake_api.dart';

const topologyActionText = GuildChannel(
  id: 'text-1',
  name: 'Общее',
  kind: ChannelKind.text,
  admissionClosed: false,
);
const topologyActionVoice = GuildChannel(
  id: 'voice-1',
  name: 'Голос',
  kind: ChannelKind.voice,
  admissionClosed: false,
);

class TopologyActionApi extends TopologyTestApi {
  TopologyActionApi() {
    current = const ChannelTopology(revision: 1, categories: [
      ChannelCategory(id: 'first', name: 'Основная', channels: []),
      ChannelCategory(
        id: 'second',
        name: 'Дополнительная',
        channels: [topologyActionText, topologyActionVoice],
      ),
    ]);
  }

  String? archivedId, closedId, movedId, targetId;
  int? mutationRevision;

  @override
  Future<void> archiveTextChannel({
    required String channelId,
    required int expectedRevision,
  }) async {
    archivedId = channelId;
    mutationRevision = expectedRevision;
  }

  @override
  Future<VoiceAdmissionCloseResult> closeVoiceAdmission({
    required String channelId,
    required int expectedRevision,
  }) async {
    closedId = channelId;
    mutationRevision = expectedRevision;
    return VoiceAdmissionCloseResult(
      channelId: channelId,
      revision: expectedRevision + 1,
      revokedLeases: 0,
    );
  }

  @override
  Future<void> moveChannel({
    required String channelId,
    required String categoryId,
    required int expectedRevision,
  }) async {
    movedId = channelId;
    targetId = categoryId;
    mutationRevision = expectedRevision;
  }
}
