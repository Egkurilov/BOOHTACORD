import '../../../models.dart';
import '../../../core/http/facade_base.dart';
import 'api.dart';

mixin VoiceLeasesFacade on ApiFacadeBase {
  late final _voiceLeases = VoiceLeasesApi(transport);

  Future<(String, VoiceCredential)> voiceCredential(
    String channelId, {
    bool transfer = false,
  }) => transport.run(
    () => _voiceLeases.voiceCredential(channelId, transfer: transfer),
  );

  Future<void> releaseVoice(String leaseId) => transport.run(
    () => _voiceLeases.releaseVoice(leaseId),
    allowClosed: true,
  );
}
