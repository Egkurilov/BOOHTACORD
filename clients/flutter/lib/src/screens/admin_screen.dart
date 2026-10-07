import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../features/admin/workspace/ports.dart';
import '../features/admin/workspace/workspace.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({
    super.key,
    required this.state,
    this.onToggleNavigation,
    this.onClose,
  });

  final AppState state;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => AdminWorkspace(
    ports: AdminWorkspacePorts(
      api: state.api,
      topology: () => state.topology,
      refreshTopology: state.refreshTopology,
      refreshGuildProfile: () => state.guildProfile.refresh(),
      refreshPermissions: state.permissions.refresh,
      closePanel: () => state.toggleWorkspacePanel(WorkspacePanel.none),
      currentAccountId: () => state.user?.accountId,
      voiceParticipantIds: () => _voiceParticipantIds(state),
    ),
    onToggleNavigation: onToggleNavigation,
    onClose: onClose,
  );

  Set<String> _voiceParticipantIds(AppState state) {
    if (state.voiceChannel == null) return const {};
    final participants = state.room?.remoteParticipants.values;
    if (participants == null) return const {};
    return participants
        .map((participant) => participant.metadata)
        .whereType<String>()
        .where((metadata) => metadata.startsWith('account:'))
        .map((metadata) => metadata.substring('account:'.length))
        .toSet();
  }
}
