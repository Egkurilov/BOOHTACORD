import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../widgets/confirmation_dialog.dart';
import 'controller.dart';
import 'surface.dart';

Future<void> showAdminVoiceTimeout(
  BuildContext context, {
  required ApiClient api,
  required String accountId,
  required String displayName,
  Listenable? scopeChanges,
}) => showConfirmationDialog<void>(
  context: context,
  builder: (_) => AdminVoiceTimeoutDialog(
    api: api,
    accountId: accountId,
    displayName: displayName,
    scopeChanges: scopeChanges,
  ),
);

class AdminVoiceTimeoutDialog extends StatefulWidget {
  const AdminVoiceTimeoutDialog({
    super.key,
    required this.api,
    required this.accountId,
    required this.displayName,
    this.scopeChanges,
  });
  final ApiClient api;
  final String accountId, displayName;
  final Listenable? scopeChanges;
  @override
  State<AdminVoiceTimeoutDialog> createState() =>
      AdminVoiceTimeoutDialogState();
}

class AdminVoiceTimeoutDialogState extends State<AdminVoiceTimeoutDialog> {
  late AdminVoiceTimeoutController owner;
  void start() {
    owner = AdminVoiceTimeoutController(widget.api, widget.accountId);
    owner.load();
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  @override
  void didUpdateWidget(covariant AdminVoiceTimeoutDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.accountId != widget.accountId) {
      owner.dispose();
      start();
    }
  }

  @override
  void dispose() {
    owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.scopeChanges ?? owner,
    builder: (context, _) => VoiceTimeoutSurface(
      owner: owner,
      displayName: widget.displayName,
      onClose: () => Navigator.pop(context),
      scopeChanges: widget.scopeChanges,
    ),
  );
}
