import '../../native_bindings.dart';

import 'widget.dart';

abstract class WorkspaceMembersPanelStateContext
    extends State<WorkspaceMembersPanel> {
  final OverlayPortalController workspaceProfilePortal =
      OverlayPortalController();
  final LayerLink workspaceProfileLink = LayerLink();
  final FocusNode workspaceProfileTriggerFocus = FocusNode(
    debugLabel: 'member-profile-trigger',
  );
  String? workspaceProfileMemberId;
  String? workspaceProfileTriggerMemberId;
  AppState get state;
  VoidCallback? get onClose;
  bool workspaceHandleHardwareKey(KeyEvent event);
  void workspaceShowMemberProfile(GuildMember member);
  void workspaceCloseMemberProfile();
  Widget workspaceBuildPanel(BuildContext context);
  Widget workspaceMemberRow(BuildContext context, GuildMember member);
  Widget workspaceMemberTile(
    BuildContext context,
    GuildMember member,
    MemberPresence memberPresence,
  );
  void workspaceMutateView(VoidCallback action) => setState(action);
}
