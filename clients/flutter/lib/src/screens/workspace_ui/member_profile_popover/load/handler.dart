import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMemberProfilePopoverStateWorkspaceLoadBinding
    on WorkspaceMemberProfilePopoverStateContext {
  @override
  Future<void> workspaceLoad() {
    return executeWorkspaceMemberProfilePopoverStateWorkspaceLoad();
  }
}

extension WorkspaceMemberProfilePopoverStateWorkspaceLoadAction
    on WorkspaceMemberProfilePopoverStateContext {
  Future<void> executeWorkspaceMemberProfilePopoverStateWorkspaceLoad() async {
    workspaceMutateView(() {
      workspaceLoading = true;
      workspaceError = null;
    });
    try {
      final member = await widget.state.api.memberProfile(widget.memberId);
      if (mounted) workspaceMutateView(() => workspaceMember = member);
    } catch (cause) {
      if (mounted) workspaceMutateView(() => workspaceError = cause.toString());
    } finally {
      if (mounted) workspaceMutateView(() => workspaceLoading = false);
    }
  }
}
