import '../lifecycle/controller.dart';
import '../../telemetry/action_scope/action.dart';
import '../../../services/client_telemetry.dart';

Future<void> observeVoiceLeave(
  VoiceController voice,
  Future<void> Function() close,
) async {
  final action = ActionScope(
    'voice.leave',
    voice.api.transport.session.telemetry,
    enabled: ClientTelemetry.enabled,
  );
  action.step('stop');
  try {
    await action.run(close);
    if (voice.room != null || voice.leaseId != null) {
      action.finish('superseded', reason: 'generation_changed');
      return;
    }
    action.step('ready');
    action.finish('success');
  } catch (_) {
    action.finish('failed', reason: 'dependency');
    rethrow;
  }
}
