import 'action.dart';
import 'session.dart';
import 'failure.dart';

Future<T> traceAction<T>(
  String name,
  TelemetrySession session,
  Future<T> Function() call, {
  required bool enabled,
  bool Function()? failed,
}) async {
  final action = ActionScope(name, session, enabled: enabled);
  action.span?.addEventNow('app.client.$name.started');
  try {
    final result = await action.run(call);
    final didFail = failed?.call() == true;
    action.span?.addEventNow(
      'app.client.$name.${didFail ? 'failed' : 'completed'}',
    );
    action.finish(
      didFail ? 'failed' : 'success',
      reason: didFail ? 'dependency' : 'none',
    );
    return result;
  } catch (cause) {
    action.span?.addEventNow('app.client.$name.failed');
    final failure = failureOutcome(cause);
    action.finish(failure.outcome, reason: failure.reason);
    rethrow;
  }
}
