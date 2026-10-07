import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import '../../../services/screen_share_metrics.dart';
import 'models.dart';
import '../metrics/stats_poller.dart';

ScreenReceiverSnapshot? screenReceiverSnapshotFromReports(List<rtc.StatsReport> reports) {
  rtc.StatsReport? selected;
  final codecs = {for (final row in reports.where((row) => row.type == 'codec')) row.id: row.values['mimeType']};
  var matches = 0;
  for (final row in reports) {
    if (row.type == 'inbound-rtp' && (row.values['kind'] ?? row.values['mediaType'] ?? 'video') == 'video' && row.values['framesDecoded'] is num) { selected = row; matches++; }
  }
  if (selected == null || matches != 1) return null;
  final row = selected;
  double? number(String key) { final value = row.values[key]; return value is num && value.isFinite ? value.toDouble() : null; }
  return ScreenReceiverSnapshot(timestampMs: webRtcStatsTimestampMs(row.timestamp), streamId: row.id, ssrc: number('ssrc'),
    codec: codecs[row.values['codecId']] is String ? codecs[row.values['codecId']] as String : null,
    decoderImplementation: row.values['decoderImplementation'] is String ? row.values['decoderImplementation'] as String : null,
    framesPerSecond: number('framesPerSecond'), bytesReceived: number('bytesReceived'), framesDecoded: number('framesDecoded'), framesDropped: number('framesDropped'),
    framesReceived: number('framesReceived'), framesRendered: number('framesRendered'), jitterSeconds: number('jitter'),
    packetsLost: number('packetsLost'), packetsReceived: number('packetsReceived'), frameWidth: number('frameWidth'), frameHeight: number('frameHeight'),
    totalDecodeTime: number('totalDecodeTime'), jitterBufferDelay: number('jitterBufferDelay'), jitterBufferEmittedCount: number('jitterBufferEmittedCount'),
    nackCount: number('nackCount'), pliCount: number('pliCount'), firCount: number('firCount'), freezeCount: number('freezeCount'), totalFreezesDuration: number('totalFreezesDuration'));
}

Future<ScreenReceiverSnapshot?> readScreenReceiverSnapshot(RemoteVideoTrack track) async {
  final receiver = track.receiver;
  if (receiver == null) {
    final stats = await track.getReceiverStats();
    if (stats == null) return null;
    return ScreenReceiverSnapshot(timestampMs: webRtcStatsTimestampMs(stats.timestamp), streamId: stats.streamId,
      bytesReceived: stats.bytesReceived?.toDouble(), framesDecoded: stats.framesDecoded?.toDouble(), framesRendered: stats.framesRendered?.toDouble(),
      framesReceived: stats.framesReceived?.toDouble(), framesDropped: stats.framesDropped?.toDouble(), jitterSeconds: stats.jitter?.toDouble(),
      packetsLost: stats.packetsLost?.toDouble(), packetsReceived: stats.packetsReceived?.toDouble(), frameWidth: stats.frameWidth?.toDouble(), frameHeight: stats.frameHeight?.toDouble(),
      framesPerSecond: stats.framesPerSecond?.toDouble(), codec: stats.mimeType, decoderImplementation: stats.decoderImplementation);
  }
  return screenReceiverSnapshotFromReports(await screenStatsPoller(receiver).read(receiver.getStats));
}
