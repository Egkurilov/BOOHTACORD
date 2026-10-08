import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMemberProfilePopoverStateBuildBinding
    on WorkspaceMemberProfilePopoverStateContext {
  @override
  Widget build(BuildContext context) {
    return executeWorkspaceMemberProfilePopoverStateBuild(context);
  }
}

extension WorkspaceMemberProfilePopoverStateBuildAction
    on WorkspaceMemberProfilePopoverStateContext {
  Widget executeWorkspaceMemberProfilePopoverStateBuild(BuildContext context) =>
      AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => workspaceBuildPopover(context),
      );
}
