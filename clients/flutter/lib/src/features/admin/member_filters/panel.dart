import 'package:flutter/material.dart';

import 'search/field.dart';
import 'role/control.dart';

class AdminMemberFilters extends StatelessWidget {
  const AdminMemberFilters({
    super.key,
    required this.search,
    required this.role,
    required this.onSearchChanged,
    required this.onRoleChanged,
  });
  final TextEditingController search;
  final String role;
  final VoidCallback onSearchChanged;
  final ValueChanged<String> onRoleChanged;
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
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: largeText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [searchField, const SizedBox(height: 8), roleField],
            )
          : Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                roleField,
              ],
            ),
    );
  }
}
