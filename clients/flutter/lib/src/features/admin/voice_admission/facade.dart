import '../../../core/http/facade_base.dart';
import 'api.dart';
import 'result.dart';

mixin VoiceAdmissionFacade on ApiFacadeBase {
  late final _voiceAdmission = VoiceAdmissionApi(transport);

  Future<VoiceAdmissionCloseResult> closeVoiceAdmission({
    required String channelId,
    required int expectedRevision,
  }) => transport.run(
    () => _voiceAdmission.closeVoiceAdmission(
      channelId: channelId,
      expectedRevision: expectedRevision,
    ),
  );
}
