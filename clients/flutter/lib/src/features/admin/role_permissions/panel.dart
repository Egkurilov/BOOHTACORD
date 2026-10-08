import 'package:flutter/material.dart';

import '../../../services/api_client.dart';
import 'lifecycle/state.dart';

class RolePermissionsPanel extends StatefulWidget {
  const RolePermissionsPanel({
    super.key,
    required this.api,
    required this.onSaved,
  });
  final ApiClient api;
  final Future<void> Function() onSaved;
  @override
  State<RolePermissionsPanel> createState() => RolePermissionsState();
}
