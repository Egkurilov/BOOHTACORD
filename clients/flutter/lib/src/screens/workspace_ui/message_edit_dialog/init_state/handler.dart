import '../../native_bindings.dart';

import '../lifecycle/context.dart';
import '../handler_bindings.dart';

mixin WorkspaceMessageEditDialogStateInitStateBinding
    on WorkspaceMessageEditDialogStateContext {
  @override
  void initState() {
    super.initState();
    executeWorkspaceMessageEditDialogStateInitState();
  }
}

extension WorkspaceMessageEditDialogStateInitStateAction
    on WorkspaceMessageEditDialogStateContext {
  void executeWorkspaceMessageEditDialogStateInitState() {
    workspaceController = TextEditingController(text: widget.initialValue);
    workspaceRevision = widget.initialRevision;
    workspaceMentionIds = widget.initialMentionIds.toSet();
  }
}
