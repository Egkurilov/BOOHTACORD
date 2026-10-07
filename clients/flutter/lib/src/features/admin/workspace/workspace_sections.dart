part of 'workspace.dart';

mixin _WorkspaceSections on _AdminWorkspaceBase {
  Widget _buildSelectedSection(BuildContext context) {
    if (_selected == AdminWorkspaceSection.guild) {
      return AdminGuildSettings(
        api: widget.ports.api,
        channels: widget.ports.topology()?.categories
                .expand((category) => category.channels)
                .toList() ??
            [],
        onSaved: widget.ports.refreshGuildProfile,
      );
    }
    if (_selected == AdminWorkspaceSection.roles) {
      return RolePermissionsPanel(
        key: _roleKey,
        api: widget.ports.api,
        onSaved: widget.ports.refreshPermissions,
      );
    }
    if (_selected == AdminWorkspaceSection.audit) {
      return AdminAuditPanel(controller: _audit);
    }
    if (_selected == AdminWorkspaceSection.media) {
      return AdminMediaMetricsPanel(api: widget.ports.api);
    }
    if (_selected == AdminWorkspaceSection.readiness) {
      return AdminReadinessPanel(api: widget.ports.api);
    }
    if (_selected == AdminWorkspaceSection.members) {
      return AdminMembersPanel(
        controller: _members,
        currentAccountId: widget.ports.currentAccountId(),
        voiceParticipantIds: widget.ports.voiceParticipantIds(),
      );
    }
    return _buildTopology();
  }

  Widget _buildTopology() => AnimatedBuilder(
    animation: _topology,
    builder: (context, _) {
      final current = widget.ports.topology();
      return AdminTopologyPanel(
        categories: current?.categories ?? const <ChannelCategory>[],
        revision: current?.revision ?? 0,
        busy: _topology.busy,
        status: _topology.status,
        error: _topology.error,
        actions: _topology.actions,
      );
    },
  );

}
