part of 'workspace.dart';

mixin _WorkspaceSections on _AdminWorkspaceBase {
  Widget _buildSelectedSection(BuildContext context) {
    if (_selected == AdminWorkspaceSection.guild) {
      return AdminGuildSettings(
        api: widget.state.api,
        channels: widget.state.topology?.categories
                .expand((category) => category.channels)
                .toList() ??
            [],
        onSaved: widget.state.guildProfile.refresh,
      );
    }
    if (_selected == AdminWorkspaceSection.roles) {
      return RolePermissionsPanel(
        key: _roleKey,
        api: widget.state.api,
        onSaved: widget.state.permissions.refresh,
      );
    }
    if (_selected == AdminWorkspaceSection.audit) {
      return AdminAuditPanel(controller: _audit);
    }
    if (_selected == AdminWorkspaceSection.media) {
      return AdminMediaMetricsPanel(api: widget.state.api);
    }
    if (_selected == AdminWorkspaceSection.readiness) {
      return AdminReadinessPanel(api: widget.state.api);
    }
    if (_selected == AdminWorkspaceSection.members) {
      return AdminMembersPanel(
        controller: _members,
        currentAccountId: widget.state.user?.accountId,
        voiceParticipantIds: _voiceParticipantIds,
      );
    }
    return _buildTopology();
  }

  Widget _buildTopology() => AnimatedBuilder(
    animation: _topology,
    builder: (context, _) => AdminTopologyPanel(
      categories: widget.state.topology?.categories ?? const <ChannelCategory>[],
      revision: widget.state.topology?.revision ?? 0,
      busy: _topology.busy,
      status: _topology.status,
      error: _topology.error,
      actions: _topology.actions,
    ),
  );

  Set<String> get _voiceParticipantIds {
    if (widget.state.voiceChannel == null) return const {};
    final participants = widget.state.room?.remoteParticipants.values;
    if (participants == null) return const {};
    return participants
        .map((participant) => participant.metadata)
        .whereType<String>()
        .where((metadata) => metadata.startsWith('account:'))
        .map((metadata) => metadata.substring('account:'.length))
        .toSet();
  }
}
