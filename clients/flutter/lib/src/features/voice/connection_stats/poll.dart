import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart'
    hide ChatMessage, voiceReconnectAttemptLimit;

import '../../../services/voice_connection_quality.dart';
import '../../../services/screen_share_metrics.dart';
import '../../../telemetry/report_media/connection.dart';
import '../lifecycle/controller.dart';
import '../audio_diagnostics/collect.dart';
import '../audio_diagnostics/telemetry.dart';

extension VoiceConnectionStatsPoll on VoiceController {
  void startVoiceConnectionStatsPolling(Room room) {
    stopVoiceConnectionStatsPolling();
    final revision = voiceConnectionStatsRevision;
    final ticket = scope.capture();
    final audioCollector = VoiceAudioCollector(captureProbe: audio.nativeNoise);
    final audioReporter = VoiceAudioTelemetry();
    final platform = nativeScreenMetricsPlatform(defaultTargetPlatform);
    final reporter = platform == null
        ? null
        : ConnectionMediaReporter(api.reportScreenShareMetrics, platform);

    Future<void> sample() async {
      if (!ticket.isActive ||
          voiceConnectionStatsBusy ||
          revision != voiceConnectionStatsRevision ||
          !identical(this.room, room) ||
          (voicePhase != VoicePhase.connected &&
              voicePhase != VoicePhase.listener)) {
        return;
      }
      voiceConnectionStatsBusy = true;
      try {
        final audioSnapshot = await audioCollector.read(room);
        final reports = await room.getPeerConnectionStats()
            .timeout(const Duration(milliseconds: 1500))
            .catchError((Object _) => <List<rtc.StatsReport>>[]);
        if (!ticket.isActive ||
            revision != voiceConnectionStatsRevision ||
            !identical(this.room, room) ||
            (voicePhase != VoicePhase.connected &&
                voicePhase != VoicePhase.listener)) {
          return;
        }
        final measuredPing = voiceRttMillisecondsFromPeerConnections(reports);
        voiceAudioDiagnostics = audioSnapshot;
        audioReporter.submit(audioSnapshot);
        if (reporter != null) {
          unawaited(
            reporter.submit(
              measuredPing,
              room.localParticipant?.connectionQuality ??
                  ConnectionQuality.unknown,
            ),
          );
        }
        final ping = voicePingAfterMeasurement(
          previousPingMilliseconds: voicePingMs,
          measuredPingMilliseconds: measuredPing,
        );
        voicePingMs = ping;
        notifyListeners();
      } catch (_) {
        // Keep voice controls working if this platform can't read connection
        // stats; track-scoped LiveKit stats can still provide audio RTT.
      } finally {
        if (revision == voiceConnectionStatsRevision) {
          voiceConnectionStatsBusy = false;
        }
      }
    }

    voiceConnectionStatsTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(sample()),
    );
    unawaited(sample());
  }

  void stopVoiceConnectionStatsPolling() {
    voiceConnectionStatsRevision++;
    voiceConnectionStatsTimer?.cancel();
    voiceConnectionStatsTimer = null;
    voiceConnectionStatsBusy = false;
    voiceAudioDiagnostics = null;
  }
}
