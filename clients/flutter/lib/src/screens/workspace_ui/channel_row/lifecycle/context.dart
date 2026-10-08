import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceChannelRowStateContext
    extends State<WorkspaceChannelRow> {
  bool workspaceHovered = false;
  bool workspaceFocused = false;
  bool get workspaceShowObjectMenu;
  void workspaceMutateView(VoidCallback action) => setState(action);
}
