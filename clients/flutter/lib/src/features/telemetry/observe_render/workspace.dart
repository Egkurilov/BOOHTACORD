import 'package:flutter/widgets.dart';

import '../action_scope/action.dart';

void observeWorkspaceReady(ActionScope scope, bool Function() ready) {
  if (!scope.enabled) {
    scope.finish('cancelled');
    return;
  }
  scope.step('render');
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (ready() && scope.session.current(scope.snapshot)) {
      scope.finish('success');
    } else {
      scope.finish('superseded', reason: 'generation_changed');
    }
  });
}
