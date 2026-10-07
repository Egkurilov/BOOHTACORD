import 'counter_window.dart';
import 'models.dart';

class ScreenShareSenderReport {
  const ScreenShareSenderReport({required this.platform, required this.state,
    this.frameWidth, this.frameHeight, this.encodedFps, this.bitrateKbps,
    this.roundTripTimeMs});
  final String platform, state;
  final int? frameWidth, frameHeight;
  final double? encodedFps, bitrateKbps, roundTripTimeMs;

  Map<String, Object> toJson() => {
    'platform': platform, 'direction': 'sender', 'state': state,
    'frame_width': ?frameWidth, 'frame_height': ?frameHeight,
    'encoded_fps': ?encodedFps, 'bitrate_kbps': ?bitrateKbps,
    'rtt_ms': ?roundTripTimeMs,
  };
}

ScreenShareSenderReport buildScreenShareSenderReport({
  required ScreenShareSenderSnapshot? previous,
  required ScreenShareSenderSnapshot? current,
  String platform = 'android_native',
}) {
  if (current == null) {
    return ScreenShareSenderReport(platform: platform, state: 'waiting_first_frame');
  }
  final elapsed = previous == null ? null : current.timestampMs - previous.timestampMs;
  final fps = screenMetricRate(previous?.framesSent, current.framesSent, elapsed, 1000, 240);
  final bitrate = screenMetricRate(previous?.bytesSent, current.bytesSent, elapsed, 8, 100000);
  final rtt = screenMetricBounded(
    current.roundTripTimeSeconds == null ? null : current.roundTripTimeSeconds! * 1000,
    60000,
  );
  final encodedFps = fps == null ? null : screenMetricRound(fps);
  final bitrateKbps = bitrate == null ? null : screenMetricRound(bitrate);
  final roundTripTimeMs = rtt == null ? null : screenMetricRound(rtt);
  return ScreenShareSenderReport(
    platform: platform,
    state: encodedFps == null && bitrateKbps == null
        ? 'waiting_first_frame' : encodedFps == 0 ? 'stalled' : 'playing',
    frameWidth: current.frameWidth,
    frameHeight: current.frameHeight,
    encodedFps: encodedFps,
    bitrateKbps: bitrateKbps,
    roundTripTimeMs: roundTripTimeMs,
  );
}
