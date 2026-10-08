enum ScreenAdaptationContent { motion, text }

enum ScreenAdaptationSource { moving, static, unknown }

enum ScreenAdaptationPublication { sharing, paused, stopped }

enum ScreenSignalProvenance {
  capture,
  senderEncoder,
  publisherNetwork,
  receiverNetwork,
  renderer,
}

enum ScreenBottleneck {
  sourceLimited,
  encoderCpuThermal,
  publisherUplink,
  receiverDownlinkDecode,
  rendering,
  unknown,
}

const sharedScreenBottlenecks = [
  ScreenBottleneck.sourceLimited,
  ScreenBottleneck.encoderCpuThermal,
  ScreenBottleneck.publisherUplink,
];

class ScreenAdaptationSignal {
  const ScreenAdaptationSignal({
    required this.provenance,
    required this.bottleneck,
    required this.pressure,
    required this.observedAtMs,
    required this.generation,
    this.receiver,
  });
  final ScreenSignalProvenance provenance;
  final ScreenBottleneck bottleneck;
  final bool pressure;
  final double observedAtMs;
  final int generation;
  final String? receiver;
  bool get receiverLocal =>
      bottleneck == ScreenBottleneck.receiverDownlinkDecode ||
      bottleneck == ScreenBottleneck.rendering;
}

class ScreenAdaptationWindow {
  const ScreenAdaptationWindow({
    required this.id,
    required this.observedAtMs,
    required this.generation,
    required this.content,
    required this.source,
    required this.visible,
    required this.warmedUp,
    required this.publication,
    required this.subscribers,
    required this.signals,
  });
  final String id;
  final double observedAtMs;
  final int generation;
  final ScreenAdaptationContent content;
  final ScreenAdaptationSource source;
  final bool visible, warmedUp;
  final ScreenAdaptationPublication publication;
  final int? subscribers;
  final List<ScreenAdaptationSignal> signals;
}
