import 'package:livekit_client/livekit_client.dart';

import '../../../services/screen_share_metrics.dart';
import 'layers.dart';

class LiveKitScreenLayerSample {
  const LiveKitScreenLayerSample(this.diagnostics, this.selected);
  final ScreenSenderLayerSample diagnostics;
  final VideoSenderStats? selected;
}

LiveKitScreenLayerSample sampleLiveKitScreenLayers(
  ScreenSenderLayerSampler sampler,
  List<VideoSenderStats> stats,
  double receivedAtMs,
) {
  final counters = stats.map((item) => ScreenSenderLayerCounters(
    streamId: item.streamId,
    rid: item.rid,
    codec: item.mimeType,
    timestampMs: webRtcStatsTimestampMs(item.timestamp),
    width: item.frameWidth,
    height: item.frameHeight,
    framesSent: item.framesSent,
    bytesSent: item.bytesSent,
    packetsSent: item.packetsSent,
    packetsLost: item.packetsLost,
    retransmittedPackets: item.retransmittedPacketsSent,
    nackCount: item.nackCount,
    pliCount: item.pliCount,
    firCount: item.firCount,
    qualityLimitationReason: item.qualityLimitationReason,
  )).toList(growable: false);
  final diagnostics = sampler.sample(counters, receivedAtMs);
  final id = diagnostics.selected?.id;
  VideoSenderStats? selected;
  if (id != null) {
    for (final item in stats) {
      if ('${item.streamId}:${item.rid ?? ''}' == id) { selected = item; break; }
    }
  }
  return LiveKitScreenLayerSample(diagnostics, selected);
}
