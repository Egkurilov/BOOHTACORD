import '../../models.dart';
import '../../features/voice/lifecycle/controller.dart';
import '../../features/workspace/lifecycle/controller.dart';
import '../composition/owners.dart';

mixin AppNavigationAccess on AppOwners {
  ChannelTopology? get topology => workspace.topology;

  set topology(ChannelTopology? value) => workspace.topology = value;

  NavigationSection get navigationSection => workspace.navigationSection;

  set navigationSection(NavigationSection value) =>
      workspace.navigationSection = value;

  WorkspacePanel get workspacePanel => workspace.workspacePanel;

  set workspacePanel(WorkspacePanel value) => workspace.workspacePanel = value;

  GuildChannel? get selectedChannel => workspace.selectedChannel;

  set selectedChannel(GuildChannel? value) => workspace.selectedChannel = value;

  void toggleWorkspacePanel(WorkspacePanel panel) =>
      workspace.toggleWorkspacePanel(panel);

  void showChannels() => workspace.showChannels();

  Future<void> refreshTopology() => workspace.refreshTopology();

  Future<void> selectChannel(GuildChannel channel) {
    voice.selectDisconnectChannel(channel.id);
    return workspace.selectChannel(channel);
  }
}
