import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import 'controller.dart';
import 'hint.dart';
import 'view.dart';

class OwnSessionsPanel extends StatefulWidget {
  const OwnSessionsPanel({
    super.key,
    required this.api,
    required this.accountId,
  });
  final ApiClient api;
  final String accountId;
  @override
  State<OwnSessionsPanel> createState() => _OwnSessionsPanelState();
}

class _OwnSessionsPanelState extends State<OwnSessionsPanel> {
  late OwnSessionsController state;
  void refresh() => unawaited(state.refresh());
  void initialize() {
    state = OwnSessionsController(
      read: widget.api.ownSessions,
      revokeOne: widget.api.revokeOwnSession,
      revokeOthersRequest: widget.api.revokeOtherSessions,
    );
    state.setAccount(widget.accountId);
    refresh();
  }

  @override
  void initState() {
    super.initState();
    initialize();
    ownSessionHints.addListener(refresh);
  }

  @override
  void didUpdateWidget(covariant OwnSessionsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      state.dispose();
      initialize();
    } else if (oldWidget.accountId != widget.accountId) {
      state.setAccount(widget.accountId);
      refresh();
    }
  }

  @override
  void dispose() {
    ownSessionHints.removeListener(refresh);
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OwnSessionsView(state: state);
}
