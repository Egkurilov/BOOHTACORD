class ScreenReceiverSnapshot {
  const ScreenReceiverSnapshot({
    required this.timestampMs,
    this.streamId, this.ssrc, this.totalDecodeTime, this.jitterBufferDelay, this.jitterBufferEmittedCount,
    this.nackCount, this.pliCount, this.firCount, this.freezeCount, this.totalFreezesDuration,
    this.bytesReceived,
    this.framesDecoded,
    this.framesRendered,
    this.framesReceived,
    this.framesDropped,
    this.jitterSeconds,
    this.packetsLost,
    this.packetsReceived,
    this.frameWidth,
    this.frameHeight,
    this.framesPerSecond,
    this.codec,
    this.decoderImplementation,
  });

  final String? streamId;
  final num? ssrc;
  final double? totalDecodeTime, jitterBufferDelay, jitterBufferEmittedCount, nackCount, pliCount, firCount, freezeCount, totalFreezesDuration;
  final double timestampMs;
  final double? bytesReceived;
  final double? framesDecoded;
  final double? framesRendered;
  final double? framesReceived;
  final double? framesDropped;
  final double? jitterSeconds;
  final double? packetsLost;
  final double? packetsReceived;
  final double? frameWidth;
  final double? frameHeight;
  final double? framesPerSecond;
  final String? codec;
  final String? decoderImplementation;
}

class ScreenReceiverMetrics {
  const ScreenReceiverMetrics({
    this.statsWindowMs, this.collectionState, this.decodeMsPerFrame, this.jitterBufferMsPerFrame,
    this.nackPerSecond, this.pliPerSecond, this.firPerSecond, this.freezeCount, this.freezeDurationMs,
    this.bitrateKbps,
    this.receivedFps,
    this.decodedFps,
    this.presentedFps,
    this.droppedFrames,
    this.jitterMs,
    this.packetsLost,
    this.packetLossPercent,
  });

  final String? collectionState;
  final double? statsWindowMs, decodeMsPerFrame, jitterBufferMsPerFrame, nackPerSecond, pliPerSecond, firPerSecond, freezeCount, freezeDurationMs;
  final double? bitrateKbps;
  final double? receivedFps;
  final double? decodedFps;
  final double? presentedFps;
  final double? droppedFrames;
  final double? jitterMs;
  final double? packetsLost;
  final double? packetLossPercent;
}
