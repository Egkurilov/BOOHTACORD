import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../models.dart';
import '../../../theme.dart';
import '../audit/controller.dart';
import '../audit/panel.dart';
import '../guild_settings/panel.dart';
import '../media_metrics/panel.dart';
import '../members/controller.dart';
import '../members/panel.dart';
import '../readiness/panel.dart';
import '../role_permissions/panel.dart';
import '../topology/mutation_controller.dart';
import '../topology/panel.dart';
import 'workspace_header.dart';

part 'workspace_layout.dart';
part 'workspace_navigation.dart';
part 'workspace_tabs.dart';
part 'workspace_sections.dart';

enum AdminWorkspaceSection { members, roles, channels, audit, media, guild, readiness }

class AdminWorkspace extends StatefulWidget {
  const AdminWorkspace({
    super.key,
    required this.state,
    this.onToggleNavigation,
    this.onClose,
  });

  final AppState state;
  final VoidCallback? onToggleNavigation;
  final VoidCallback? onClose;

  @override
  State<AdminWorkspace> createState() => _AdminWorkspaceState();
}

abstract class _AdminWorkspaceBase extends State<AdminWorkspace> {
  final _roleKey = GlobalKey<RolePermissionsPanelState>();
  final _titleFocus = FocusNode(debugLabel: 'admin-screen-title');
  late final AdminMembersController _members;
  late final AdminAuditController _audit;
  late final AdminTopologyMutationController _topology;
  AdminWorkspaceSection _selected = AdminWorkspaceSection.members;

  Widget _buildWorkspace(BuildContext context);
  Future<void> _closeWorkspace();
  Future<void> _selectSection(AdminWorkspaceSection section);
  Widget _buildNavigation(BuildContext context, double width);
  Widget _buildSelectedSection(BuildContext context);

  @override
  void initState() {
    super.initState();
    _members = AdminMembersController(widget.state.api);
    _audit = AdminAuditController(
      ({String? before}) => widget.state.api.listAdminAudit(before: before),
    );
    _topology = AdminTopologyMutationController(widget.state, () => context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _titleFocus.requestFocus();
      unawaited(_members.load());
    });
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _members.dispose();
    _audit.dispose();
    _topology.dispose();
    super.dispose();
  }
}

class _AdminWorkspaceState extends _AdminWorkspaceBase
    with
        _WorkspaceLayout,
        _WorkspaceNavigation,
        _WorkspaceTabs,
        _WorkspaceSections {
  @override
  Widget build(BuildContext context) => _buildWorkspace(context);
}
