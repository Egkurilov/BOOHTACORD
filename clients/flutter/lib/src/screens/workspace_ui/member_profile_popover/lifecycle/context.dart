import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceMemberProfilePopoverStateContext
    extends State<WorkspaceMemberProfilePopover> {
  GuildMember? workspaceMember;
  String? workspaceError;
  String? workspaceStatus;
  bool workspaceLoading = true;
  bool workspaceKicking = false;
  Future<void> workspaceLoad();
  Future<void> workspaceKick(RemoteParticipant participant);
  Widget workspaceBuildPopover(BuildContext context);
  void workspaceMutateView(VoidCallback action) => setState(action);
}
