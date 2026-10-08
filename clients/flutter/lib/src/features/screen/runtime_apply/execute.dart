import '../slow_policy/evaluate.dart';
import '../slow_policy/state.dart';
import '../slow_policy/types.dart';
import 'runtime.dart';
import 'port.dart';

extension ScreenRuntimeExecution on ScreenAdaptationRuntime {
  Future<void> execute(
    ScreenAdaptationWindow window,
    ScreenRuntimeBinding initial,
    int own,
  ) async {
    if (!live(initial, own)) {
      invalidate();
      return;
    }
    if (binding == null || !binding!.same(initial)) {
      policyState = ScreenAdaptationState(
        initial.current,
        initial.ceiling,
        initial.generation,
      );
      binding = initial;
      attempts = 0;
    }
    final result = evaluateScreenAdaptation(
      policyState!,
      window,
      now,
      options.calibration,
    );
    reason = result.reason;
    final target = result.profile;
    if (target == null) {
      policyState = result.state;
      return;
    }
    if (!port.canApply(target, initial)) {
      policyState!.resetTrend();
      reason = 'capture-restart-required';
      return;
    }
    if (attempts >= options.calibration!.maxTransitions) {
      reason = 'attempt-limit';
      return;
    }
    attempts++;
    try {
      final applied = await port.write(target), after = port.read();
      if (own != sequence || !initial.same(after, ownWrite: true)) {
        invalidate();
        return;
      }
      if (!applied || after!.current != target) {
        policyState!.resetTrend();
        binding = after;
        reason = 'writer-not-applied';
        return;
      }
      policyState = result.state;
      binding = after;
    } catch (_) {
      if (own != sequence || !initial.same(port.read(), ownWrite: true)) {
        invalidate();
      } else {
        policyState!.resetTrend();
        binding = port.read();
        reason = 'writer-failed';
      }
    }
  }
}
