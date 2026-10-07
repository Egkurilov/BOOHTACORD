import '../screens/screen_receiver_diagnostics.dart';

Map<String, Object>? buildScreenReceiverReport({
  required String platform,
  required bool selected,
  required bool hasTrack,
  required ScreenReceiverSnapshot? current,
  required ScreenReceiverMetrics? metrics,
  int? sampleAgeMs,
  double? packetLossWindowMs,
}) {
  if (!selected ||
      (sampleAgeMs != null && (sampleAgeMs < 0 || sampleAgeMs > 15000))) {
    return null;
  }

  final width = _pixelDimension(current?.frameWidth);
  final height = _pixelDimension(current?.frameHeight);
  final decodedFps = _bounded(metrics?.decodedFps, 240);
  final presentedFps = _bounded(metrics?.presentedFps, 240);
  final loss = _bounded(metrics?.packetLossPercent, 100);
  final state = !hasTrack
      ? 'waiting_subscription'
      : current == null
      ? 'waiting_first_frame'
      : presentedFps == 0
      ? 'stalled'
      : width != null && height != null
      ? 'playing'
      : 'waiting_first_frame';

  return {
    'platform': platform,
    'direction': 'receiver',
    'presentation_source': 'unsupported',
    'stats_source': metrics?.statsWindowMs == null && metrics?.freezeCount == null && metrics?.freezeDurationMs == null ? 'unsupported' : 'webrtc_interval',
    'collection_state': metrics?.collectionState ?? 'unavailable',
    'freeze_count': ?_boundedInt(metrics?.freezeCount, 1000000000),
    'freeze_duration_ms': ?_bounded(metrics?.freezeDurationMs, 86400000),
    if (metrics?.statsWindowMs != null) ...{
      'stats_window_ms': metrics!.statsWindowMs!,
      'decode_ms_per_frame': ?_bounded(metrics.decodeMsPerFrame, 60000),
      'jitter_buffer_ms_per_frame': ?_bounded(metrics.jitterBufferMsPerFrame, 60000),
      'nack_per_second': ?_bounded(metrics.nackPerSecond, 1000000),
      'pli_per_second': ?_bounded(metrics.pliPerSecond, 1000000),
      'fir_per_second': ?_bounded(metrics.firPerSecond, 1000000),

    },
    'sample_age_ms': ?sampleAgeMs,
    if (loss != null &&
        packetLossWindowMs != null &&
        packetLossWindowMs >= 9000 &&
        packetLossWindowMs <= 12000) ...{
      'packet_loss_percent': loss,
      'packet_loss_window_ms': packetLossWindowMs,
    },
    'state': state,
    if (width != null && height != null) ...{
      'frame_width': width,
      'frame_height': height,
    },
    'decoded_fps': ?decodedFps,
    // Native renderer counters are not proof of presentation; keep absent.
    'bitrate_kbps': ?_bounded(metrics?.bitrateKbps, 100000),
    'jitter_ms': ?_bounded(metrics?.jitterMs, 60000),
    'packets_lost': ?_boundedInt(metrics?.packetsLost, 1000000000),
    'dropped_frames': ?_boundedInt(metrics?.droppedFrames, 1000000000),
  };
}

double? _bounded(double? value, double maximum) =>
    value != null && value.isFinite && value >= 0 && value <= maximum
    ? _round(value)
    : null;

int? _boundedInt(double? value, double maximum) =>
    value != null && value.isFinite && value >= 0 && value <= maximum
    ? value.floor()
    : null;

int? _pixelDimension(double? value) =>
    value != null && value.isFinite && value >= 1 && value <= 8192
    ? value.round()
    : null;

double _round(double value) => (value * 10).round() / 10;
