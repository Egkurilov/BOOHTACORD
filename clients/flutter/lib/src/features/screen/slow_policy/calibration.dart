import '../profile/quality.dart';
import 'types.dart';

class ScreenAdaptationCalibration {
  const ScreenAdaptationCalibration({
    required this.evidenceStatus,
    required this.evidenceSha,
    required this.maxSignalAgeMs,
    required this.maximumWindowGapMs,
    required this.minIndependentSources,
    required this.pressureWindows,
    required this.recoveryDurationMs,
    required this.minimumDwellMs,
    required this.maxTransitions,
    required this.ladders,
  });
  ScreenAdaptationCalibration snapshot() => ScreenAdaptationCalibration(
    evidenceStatus: evidenceStatus,
    evidenceSha: evidenceSha,
    maxSignalAgeMs: maxSignalAgeMs,
    maximumWindowGapMs: maximumWindowGapMs,
    minIndependentSources: minIndependentSources,
    pressureWindows: pressureWindows,
    recoveryDurationMs: recoveryDurationMs,
    minimumDwellMs: minimumDwellMs,
    maxTransitions: maxTransitions,
    ladders:
        Map<
          ScreenBottleneck,
          Map<ScreenAdaptationContent, List<ScreenShareQuality>>
        >.unmodifiable({
          for (final entry in ladders.entries)
            entry.key:
                Map<
                  ScreenAdaptationContent,
                  List<ScreenShareQuality>
                >.unmodifiable({
                  for (final content in entry.value.entries)
                    content.key: List<ScreenShareQuality>.unmodifiable(
                      content.value,
                    ),
                }),
        }),
  );
  final String evidenceStatus, evidenceSha;
  final double maxSignalAgeMs,
      maximumWindowGapMs,
      recoveryDurationMs,
      minimumDwellMs;
  final int minIndependentSources, pressureWindows, maxTransitions;
  final Map<
    ScreenBottleneck,
    Map<ScreenAdaptationContent, List<ScreenShareQuality>>
  >
  ladders;
  bool get valid {
    if (evidenceStatus != 'PASS' ||
        !RegExp(r'^([a-fA-F0-9]{40}|[a-fA-F0-9]{64})$').hasMatch(evidenceSha) ||
        [
          maxSignalAgeMs,
          maximumWindowGapMs,
          recoveryDurationMs,
          minimumDwellMs,
        ].any((v) => !v.isFinite || v <= 0) ||
        minIndependentSources < 2 ||
        pressureWindows < 2 ||
        maxTransitions < 1) {
      return false;
    }
    try {
      for (final kind in sharedScreenBottlenecks) {
        for (final content in ScreenAdaptationContent.values) {
          final ladder = ladders[kind]?[content];
          if (ladder == null ||
              ladder.length < 2 ||
              ladder.toSet().length != ladder.length) {
            return false;
          }
          for (var i = 0; i < ladder.length; i++) {
            ladder[i].maxBitrateBps;
            if (i > 0 &&
                (ladder[i].resolution > ladder[i - 1].resolution ||
                    ladder[i].frameRate > ladder[i - 1].frameRate)) {
              return false;
            }
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  ScreenShareQuality? step(
    ScreenBottleneck kind,
    ScreenAdaptationContent content,
    ScreenShareQuality current,
    ScreenShareQuality ceiling,
    bool down,
  ) {
    final ladder = ladders[kind]?[content];
    if (ladder == null) return null;
    final index = ladder.indexOf(current),
        cap = ladder.indexOf(ceiling),
        next = index + (down ? 1 : -1);
    if (index < 0 ||
        cap < 0 ||
        index < cap ||
        next < cap ||
        next >= ladder.length) {
      return null;
    }
    return ladder[next];
  }
}
