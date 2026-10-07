import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import '../../authorization/permissions/model.dart';
import 'model.dart';

part 'panel_actions.dart';
part 'panel_navigation.dart';
part 'panel_matrix_data.dart';
part 'panel_matrix.dart';
part 'panel_conflict_model.dart';
part 'panel_conflict.dart';
part 'panel_action_bar.dart';
part 'panel_chrome.dart';
part 'panel_view.dart';
part 'panel_load.dart';

class RolePermissionsPanel extends StatefulWidget {
  const RolePermissionsPanel({
    super.key,
    required this.api,
    required this.onSaved,
  });

  final ApiClient api;
  final Future<void> Function() onSaved;

  @override
  RolePermissionsPanelState createState() => RolePermissionsPanelState();
}

class RolePermissionsPanelState extends State<RolePermissionsPanel> {
  GuildRole role = GuildRole.member;
  int revision = 0;
  bool loading = true;
  bool saving = false;
  bool _allowPop = false;
  String? error;
  String? status;
  List<RolePolicy> roles = const [];
  Map<GuildPermission, bool> baseline = {};
  Map<GuildPermission, bool> draft = {};
  _PermissionConflict? conflictReview;

  bool get dirty => role == GuildRole.member && _different(baseline, draft);
  bool get hasPendingDraft => _different(baseline, draft);
  bool get hasPendingChanges => hasPendingDraft || conflictReview != null;
  RolePolicy? get selected => roles.where((item) => item.role == role).firstOrNull;

  static bool _different(
    Map<GuildPermission, bool> left,
    Map<GuildPermission, bool> right,
  ) => GuildPermission.values.any((key) => left[key] != right[key]);

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) => _buildPanel(context);

  Future<bool> confirmBeforeLeaving() => _confirmBeforeLeaving();
}
