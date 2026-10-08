import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceCategoryStateContext extends State<WorkspaceCategory> {
  bool workspaceExpanded = true;
  bool workspaceHovered = false;
  bool workspaceFocused = false;
  bool get workspaceShowObjectMenu;
  void workspaceMutateView(VoidCallback action) => setState(action);
}
