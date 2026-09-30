class SenderMediaSample {
  const SenderMediaSample({
    required this.streamId,
    required this.timestamp,
    this.frameWidth,
    this.frameHeight,
    this.packetsSent,
    this.packetsLost,
    this.qualityLimitationReason,
  });
  final String streamId;
  final num timestamp;
  final num? frameWidth, frameHeight, packetsSent, packetsLost;
  final String? qualityLimitationReason;
}
