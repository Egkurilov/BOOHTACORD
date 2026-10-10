import 'package:flutter/material.dart';

import 'search/field.dart';
import 'role/control.dart';
import 'status/control.dart';

class AdminMemberFilters extends StatelessWidget {
  const AdminMemberFilters({
    super.key,
    required this.search,
    required this.role,
    required this.status,
    required this.onSearchChanged,
    required this.onRoleChanged,
    required this.onStatusChanged,
  });
  final TextEditingController search;
  final String role;
  final String status;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onStatusChanged;
  @override
  Widget build(BuildContext context) {
    final searchField = AdminMemberSearch(
      search: search,
      onSearchChanged: onSearchChanged,
    );
    final roleField = AdminMemberRoleFilter(
      role: role,
      onRoleChanged: onRoleChanged,
    );
    final statusField = AdminMemberStatusFilter(
      status: status,
      onStatusChanged: onStatusChanged,
    );
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    final compact = MediaQuery.sizeOf(context).width <= 720;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: compact || largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: roleField),
                    const SizedBox(width: 8),
                    Expanded(child: statusField),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                roleField,
                const SizedBox(width: 8),
                statusField,
              ],
            ),
    );
  }
}
