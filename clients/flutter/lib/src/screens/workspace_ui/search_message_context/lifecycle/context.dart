import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceSearchMessageContextStateContext
    extends State<WorkspaceSearchMessageContext> {
  final workspaceTargetKey = GlobalKey();
  String? workspaceLastTargetId;
  void workspaceMutateView(VoidCallback action) => setState(action);
}
