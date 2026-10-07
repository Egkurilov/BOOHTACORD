import 'package:flutter/material.dart';

import '../app_state.dart';
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
    state: state,
    onToggleNavigation: onToggleNavigation,
    onClose: onClose,
  );
}
