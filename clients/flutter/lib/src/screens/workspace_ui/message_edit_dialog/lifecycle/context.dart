import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceMessageEditDialogStateContext
    extends State<WorkspaceMessageEditDialog> {
  late final TextEditingController workspaceController;
  late int workspaceRevision;
  late final Set<String> workspaceMentionIds;
  bool workspacePending = false;
  bool workspaceNeedsRefresh = false;
  String? workspaceError;
  String? workspaceNotice;
  Future<void> workspaceSave();
  Future<void> workspaceRefresh();
  void workspaceMutateView(VoidCallback action) => setState(action);
}
