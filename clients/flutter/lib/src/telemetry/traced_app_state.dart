import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:livekit_client/livekit_client.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/client_telemetry.dart';
import '../services/screen_share_quality.dart';

class TracedAppState extends AppState {
  TracedAppState(super.api, {super.audioDeviceBootstrap}) {
    addListener(_watchVoiceReconnect);
  }

  Span? _reconnectSpan;

  void _watchVoiceReconnect() {
    if (!ClientTelemetry.enabled) return;
    if (voicePhase == VoicePhase.reconnecting) {
      if (_reconnectSpan == null) {
        _reconnectSpan = OTel.tracer().startSpan('voice.reconnect');
        _reconnectSpan!.addEventNow('app.client.voice.reconnect.started');
      }
    } else if (_reconnectSpan != null) {
      final failed =
          voicePhase != VoicePhase.connected &&
          voicePhase != VoicePhase.listener;
      if (failed) {
        _reconnectSpan!.setStatus(SpanStatusCode.Error);
      }
      _reconnectSpan!.addEventNow(
        'app.client.voice.reconnect.${failed ? 'failed' : 'completed'}',
      );
      _reconnectSpan!.end();
      _reconnectSpan = null;
    }
  }

  @override
  Future<void> joinVoice(GuildChannel channel, {bool listenerOnly = false}) =>
      ClientTelemetry.trace(
        'voice.join',
        () => super.joinVoice(channel, listenerOnly: listenerOnly),
        failed: () => voicePhase == VoicePhase.error,
      );

  @override
  Future<void> leaveVoice() =>
      ClientTelemetry.trace('voice.leave', super.leaveVoice);

  @override
  Future<void> startScreenShare({
    String? sourceId,
    ScreenShareQuality? quality,
    VideoDimensions? sourceDimensions,
  }) => ClientTelemetry.trace(
    'screen.share.start',
    () => super.startScreenShare(
      sourceId: sourceId,
      quality: quality,
      sourceDimensions: sourceDimensions,
    ),
    failed: () => screenSharePhase == ScreenSharePhase.error,
  );

  @override
  Future<void> stopScreenShare() =>
      ClientTelemetry.trace('screen.share.stop', super.stopScreenShare);

  @override
  void dispose() {
    removeListener(_watchVoiceReconnect);
    _reconnectSpan?.addEventNow('app.client.voice.reconnect.failed');
    _reconnectSpan?.end();
    super.dispose();
  }
}
