import 'package:flutter/widgets.dart';

import '../action_scope/action.dart';
import '../action_scope/session.dart';
import '../../../services/client_telemetry.dart';
import '../action_scope/failure.dart';

final _render = Expando<Map<ActionScope, void Function()>>();
void awaitMessageRender(Object message, ActionScope scope) {
  scope.step('ack');
  scope.step('render');
  final waiting = _render[message] ?? <ActionScope, void Function()>{};
  waiting[scope] = () => scope.finish('success');
  _render[message] = waiting;
  scope.onFinish(() => waiting.remove(scope));
}

void observeMessageRender(Object message, BuildContext context) {
  final waiting = _render[message];
  if (waiting == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (context.mounted && identical(_render[message], waiting)) {
      _render[message] = null;
      for (final complete in waiting.values.toList()) {
        complete();
      }
    }
  });
}

class SendObservation {
  SendObservation(this.session);
  final TelemetrySession session;
  final _intents = <String, ActionScope>{};
  ActionScope begin(String id) {
    final previous = _intents[id],
        scope =
            previous?.retry() ??
            ActionScope(
              'message.send',
              session,
              enabled: ClientTelemetry.enabled,
            );
    _intents[id] = scope;
    scope.step('request');
    return scope;
  }

  void accepted(String id, Object message) {
    final scope = _intents.remove(id);
    if (scope != null) awaitMessageRender(message, scope);
  }

  void failed(String id, [Object? cause]) {
    final failure = failureOutcome(cause);
    _intents[id]?.finish(failure.outcome, reason: failure.reason);
  }

  void clear() {
    for (final scope in _intents.values) {
      scope.finish('superseded', reason: 'disposed');
    }
    _intents.clear();
  }
}
