import 'package:flutter/foundation.dart';

String? nativeScreenMetricsPlatform(TargetPlatform platform) =>
    switch (platform) {
      TargetPlatform.android => 'android_native',
      TargetPlatform.iOS => 'ios_native',
      TargetPlatform.macOS => 'macos_native',
      TargetPlatform.windows => 'windows_native',
      _ => null,
    };

// flutter_webrtc forwards RTCStats.timestamp_us without converting its unit.
double webRtcStatsTimestampMs(num timestampUs) => timestampUs / 1000;

class ScreenShareSenderStats {
  const ScreenShareSenderStats({
    required this.timestampMs,
    this.frameWidth,
    this.frameHeight,
    this.bytesSent,
    this.framesSent,
    this.framesPerSecond,
    this.roundTripTimeSeconds,
  });

  final double timestampMs;
  final num? frameWidth;
  final num? frameHeight;
  final num? bytesSent;
  final num? framesSent;
  final num? framesPerSecond;
  final num? roundTripTimeSeconds;
}

class ScreenShareSenderSnapshot {
  const ScreenShareSenderSnapshot({
    required this.timestampMs,
    this.frameWidth,
    this.frameHeight,
    this.bytesSent,
    this.framesSent,
    this.framesPerSecond,
    this.roundTripTimeSeconds,
  });

  final double timestampMs;
  final int? frameWidth;
  final int? frameHeight;
  final double? bytesSent;
  final double? framesSent;
  final double? framesPerSecond;
  final double? roundTripTimeSeconds;
}

ScreenShareSenderSnapshot? screenShareSenderSnapshotFromStats(
  List<ScreenShareSenderStats> stats,
) {
  if (stats.isEmpty) return null;
  final selected = stats.reduce((best, candidate) {
    final bestPixels = (best.frameWidth ?? 0) * (best.frameHeight ?? 0);
    final candidatePixels =
        (candidate.frameWidth ?? 0) * (candidate.frameHeight ?? 0);
    return candidatePixels > bestPixels ? candidate : best;
  });
  final byteCounters = stats
      .map((item) => item.bytesSent)
      .where((value) => value != null && value.isFinite && value >= 0)
      .cast<num>()
      .toList(growable: false);
  final frameWidth = _pixelDimension(selected.frameWidth);
  final frameHeight = _pixelDimension(selected.frameHeight);
  return ScreenShareSenderSnapshot(
    timestampMs: selected.timestampMs,
    frameWidth: frameWidth == null || frameHeight == null ? null : frameWidth,
    frameHeight: frameWidth == null || frameHeight == null ? null : frameHeight,
    bytesSent: byteCounters.isEmpty
        ? null
        : byteCounters.fold<double>(0, (sum, value) => sum + value),
    framesSent: _validCounter(selected.framesSent),
    framesPerSecond: _validCounter(selected.framesPerSecond),
    roundTripTimeSeconds: _validCounter(selected.roundTripTimeSeconds),
  );
}

class ScreenShareSenderReport {
  const ScreenShareSenderReport({
    required this.platform,
    required this.state,
    this.frameWidth,
    this.frameHeight,
    this.encodedFps,
    this.bitrateKbps,
    this.roundTripTimeMs,
  });

  final String platform;
  final String state;
  final int? frameWidth;
  final int? frameHeight;
  final double? encodedFps;
  final double? bitrateKbps;
  final double? roundTripTimeMs;

  Map<String, Object> toJson() => {
    'platform': platform,
    'direction': 'sender',
    'state': state,
    'frame_width': ?frameWidth,
    'frame_height': ?frameHeight,
    'encoded_fps': ?encodedFps,
    'bitrate_kbps': ?bitrateKbps,
    'rtt_ms': ?roundTripTimeMs,
  };
}

ScreenShareSenderReport buildScreenShareSenderReport({
  required ScreenShareSenderSnapshot? previous,
  required ScreenShareSenderSnapshot? current,
  String platform = 'android_native',
}) {
  if (current == null) {
    return ScreenShareSenderReport(
      platform: platform,
      state: 'waiting_first_frame',
    );
  }
  final elapsedMs = previous == null
      ? null
      : current.timestampMs - previous.timestampMs;
  final encodedFps =
      _bounded(current.framesPerSecond, 240) ??
      _rate(previous?.framesSent, current.framesSent, elapsedMs, 1000, 240);
  final bitrateKbps =
      current.bytesSent == null ||
          !current.bytesSent!.isFinite ||
          current.bytesSent! < 0
      ? null
      : _rate(previous?.bytesSent, current.bytesSent, elapsedMs, 8, 100000);
  final roundTripTimeMs = current.roundTripTimeSeconds == null
      ? null
      : _bounded(current.roundTripTimeSeconds! * 1000, 60000);
  final fps = encodedFps == null ? null : _round(encodedFps, 1);
  final bitrate = bitrateKbps == null ? null : _round(bitrateKbps, 1);
  final rtt = roundTripTimeMs == null ? null : _round(roundTripTimeMs, 1);
  return ScreenShareSenderReport(
    platform: platform,
    state: fps == null && bitrate == null
        ? 'waiting_first_frame'
        : fps == 0
        ? 'stalled'
        : 'playing',
    frameWidth: current.frameWidth,
    frameHeight: current.frameHeight,
    encodedFps: fps,
    bitrateKbps: bitrate,
    roundTripTimeMs: rtt,
  );
}

double? _bounded(double? value, double maximum) =>
    value != null && value.isFinite && value >= 0 && value <= maximum
    ? value
    : null;

double? _validCounter(num? value) =>
    value != null && value.isFinite && value >= 0 ? value.toDouble() : null;

int? _pixelDimension(num? value) =>
    value != null && value.isFinite && value >= 1 && value <= 8192
    ? value.round()
    : null;

double? _rate(
  double? previous,
  double? current,
  double? elapsedMs,
  double multiplier,
  double maximum,
) {
  if (previous == null ||
      current == null ||
      elapsedMs == null ||
      !previous.isFinite ||
      !current.isFinite ||
      !elapsedMs.isFinite ||
      elapsedMs <= 0 ||
      current < previous) {
    return null;
  }
  return _bounded((current - previous) * multiplier / elapsedMs, maximum);
}

double _round(double value, int places) {
  final multiplier = places == 0 ? 1.0 : 10.0;
  return (value * multiplier).round() / multiplier;
}
