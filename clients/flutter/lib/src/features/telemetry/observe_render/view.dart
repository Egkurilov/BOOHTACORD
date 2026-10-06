import '../action_scope/action.dart';
import '../action_scope/session.dart';
import '../../../services/client_telemetry.dart';

final _views = Expando<ActionScope>();
ActionScope beginView(TelemetrySession session) {
  final previous = _views[session];
  previous?.finish('superseded');
  final action = ActionScope(
    'screen.view',
    session,
    enabled: ClientTelemetry.enabled,
  );
  action.step('select');
  action.step('subscribe');
  action.step('first_frame');
  _views[session] = action;
  return action;
}

ActionScope claimView(TelemetrySession session) {
  final current = _views[session];
  return current != null &&
          !current.complete &&
          session.current(current.snapshot)
      ? current
      : beginView(session);
}

void stopView(TelemetrySession session) {
  _views[session]?.finish('cancelled');
  _views[session] = null;
}
