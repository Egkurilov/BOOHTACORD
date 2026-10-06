import '../../../models.dart';
import '../lifecycle/controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../../services/client_telemetry.dart';

Future<void> observeVoiceAdmission(
  VoiceController voice,
  GuildChannel channel,
  bool listen,
  Future<void> Function() join,
) async {
  if (voice.room != null && voice.voiceChannel?.id == channel.id ||
      voice.voiceAdmissionPending) {
    return;
  }
  final telemetry = voice.api.transport.session.telemetry;
  telemetry.beginMedia();
  final action = ActionScope(
    'voice.join',
    telemetry,
    enabled: ClientTelemetry.enabled,
  );
  telemetry.mediaFlow = action.id;
  try {
    await action.run(join);
    action.span?.setStringAttribute(
      'app.voice.mode',
      voice.microphoneUnavailable
          ? 'microphone_unavailable'
          : voice.listenerOnly
          ? 'listener'
          : 'participant',
    );
    final ready =
        voice.room != null &&
        voice.voiceChannel?.id == channel.id &&
        (voice.voicePhase == VoicePhase.connected ||
            voice.voicePhase == VoicePhase.listener);
    action.finish(
      ready
          ? 'success'
          : voice.voicePhase == VoicePhase.error
          ? 'failed'
          : 'cancelled',
      reason: ready ? 'none' : 'dependency',
    );
    if (!ready) telemetry.endMedia();
  } catch (_) {
    action.finish('failed', reason: 'dependency');
    telemetry.endMedia();
    rethrow;
  }
}
