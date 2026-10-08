import '../slow_policy/state.dart';
import '../slow_policy/types.dart';
import 'options.dart';
import 'port.dart';
import 'execute.dart';
export 'execute.dart';

class ScreenAdaptationRuntime {
  ScreenAdaptationRuntime(this.port, ScreenAdaptationOptions options)
    : options = options.snapshot();
  final ScreenAdaptationPort port;
  final ScreenAdaptationOptions options;
  final clock = Stopwatch()..start();
  ScreenAdaptationState? policyState;
  ScreenRuntimeBinding? binding;
  int sequence = 0, attempts = 0;
  bool busy = false;
  String reason = 'disabled-unvalidated';
  ScreenAdaptationState? get state =>
      policyState == null ? null : ScreenAdaptationState.copy(policyState!);
  double get now => options.now?.call() ?? clock.elapsedMilliseconds.toDouble();
  void invalidate() {
    sequence++;
    policyState = null;
    binding = null;
    attempts = 0;
  }

  bool live(ScreenRuntimeBinding initial, int own) =>
      own == sequence && initial.same(port.read());
  Future<void> step(ScreenAdaptationWindow window) async {
    if (!options.admitted || busy) return;
    final initial = port.read();
    if (initial == null || !initial.active) {
      invalidate();
      return;
    }
    busy = true;
    try {
      await execute(window, initial, sequence);
    } finally {
      busy = false;
    }
  }

  Future<void> Function(ScreenAdaptationObservation)? collector() {
    if (!options.admitted || options.readWindow == null || busy) return null;
    final initial = port.read(), epoch = sequence;
    if (initial == null || !initial.active) return null;
    return (observation) => observe(
      ScreenAdaptationObservation(observation.report, observation.layers, now),
      captured: initial,
      epoch: epoch,
    );
  }

  Future<void> observe(
    ScreenAdaptationObservation observation, {
    ScreenRuntimeBinding? captured,
    int? epoch,
  }) async {
    final classifier = options.readWindow;
    if (!options.admitted || classifier == null || busy) return;
    final initial = captured ?? port.read(), own = epoch ?? sequence;
    if (initial == null || !live(initial, own)) {
      if (own == sequence) invalidate();
      return;
    }
    busy = true;
    try {
      final window = await classifier(observation, initial);
      if (!live(initial, own)) {
        if (own == sequence) invalidate();
        return;
      }
      if (window != null) await execute(window, initial, own);
    } catch (_) {
      reason = 'classifier-failed';
    } finally {
      busy = false;
    }
  }
}
