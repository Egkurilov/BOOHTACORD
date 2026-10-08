import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMembersPanelStateBuildBinding
    on WorkspaceMembersPanelStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceMembersPanelStateBuild(context);
  }
}

extension WorkspaceMembersPanelStateBuildAction
    on WorkspaceMembersPanelStateContext {
  Widget executeWorkspaceMembersPanelStateBuild(BuildContext context) =>
      AnimatedBuilder(
        animation: state,
        builder: (context, _) => workspaceBuildPanel(context),
      );
}
