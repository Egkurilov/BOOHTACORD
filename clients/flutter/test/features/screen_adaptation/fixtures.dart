import 'package:boohtacord_desktop/src/features/screen/slow_policy/types.dart';
import 'package:boohtacord_desktop/src/features/screen/slow_policy/calibration.dart';
import 'package:boohtacord_desktop/src/features/screen/profile/quality.dart';

const high = ScreenShareQuality(resolution: 1080, frameRate: 60),
    low = ScreenShareQuality(resolution: 720, frameRate: 60);
ScreenAdaptationCalibration fixtureCalibration() => ScreenAdaptationCalibration(
  evidenceStatus: 'PASS',
  evidenceSha: 'a' * 40,
  maxSignalAgeMs: 12000,
  maximumWindowGapMs: 15000,
  minIndependentSources: 2,
  pressureWindows: 3,
  recoveryDurationMs: 20000,
  minimumDwellMs: 30000,
  maxTransitions: 3,
  ladders: {
    for (final kind in sharedScreenBottlenecks)
      kind: {
        for (final content in ScreenAdaptationContent.values)
          content: [high, low],
      },
  },
);
ScreenAdaptationWindow window(
  double at, {
  bool pressure = true,
  ScreenBottleneck kind = ScreenBottleneck.publisherUplink,
  ScreenAdaptationSource source = ScreenAdaptationSource.moving,
  bool visible = true,
  bool warmedUp = true,
  int? subscribers = 2,
  int generation = 1,
}) => ScreenAdaptationWindow(
  id: '$at',
  observedAtMs: at,
  generation: generation,
  content: ScreenAdaptationContent.motion,
  source: source,
  visible: visible,
  warmedUp: warmedUp,
  publication: ScreenAdaptationPublication.sharing,
  subscribers: subscribers,
  signals: [
    for (final provenance in [
      ScreenSignalProvenance.senderEncoder,
      ScreenSignalProvenance.publisherNetwork,
    ])
      ScreenAdaptationSignal(
        provenance: provenance,
        bottleneck: kind,
        pressure: pressure,
        observedAtMs: at,
        generation: generation,
        receiver: kind == ScreenBottleneck.receiverDownlinkDecode
            ? 'synthetic'
            : null,
      ),
  ],
);
