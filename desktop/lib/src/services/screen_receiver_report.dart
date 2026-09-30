import '../screens/screen_receiver_diagnostics.dart';

Map<String, Object>? buildScreenReceiverReport({
  required String platform,
  required bool selected,
  required bool hasTrack,
  required ScreenReceiverSnapshot? current,
  required ScreenReceiverMetrics? metrics,
}) {
  if (!selected) return null;

  final width = _pixelDimension(current?.frameWidth);
  final height = _pixelDimension(current?.frameHeight);
  final decodedFps = _bounded(metrics?.decodedFps, 240);
  final state = !hasTrack
      ? 'waiting_subscription'
      : current == null
      ? 'waiting_first_frame'
      : decodedFps == 0 || current.framesPerSecond == 0
      ? 'stalled'
      : width != null && height != null
      ? 'playing'
      : 'waiting_first_frame';

  return {
    'platform': platform,
    'direction': 'receiver',
    'state': state,
    if (width != null && height != null) ...{
      'frame_width': width,
      'frame_height': height,
    },
    'decoded_fps': ?decodedFps,
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
