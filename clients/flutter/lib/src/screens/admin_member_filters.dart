import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Поиск участников',
            child: TextField(
              key: const ValueKey('admin-member-search'),
              controller: search,
              onChanged: (_) => onSearchChanged(),
              decoration: const InputDecoration(
                hintText: 'Поиск по имени или логину',
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Semantics(
            label: 'Фильтр по роли',
            child: DropdownButtonFormField<String>(
              key: const ValueKey('admin-member-role-filter'),
              initialValue: role,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: const [
                DropdownMenuItem(
                  value: 'ALL',
                  child: Text('Все роли', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'MEMBER',
                  child: Text('Пользователь', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'ADMINISTRATOR',
                  child: Text('Администратор', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: (value) {
                if (value != null) onRoleChanged(value);
              },
            ),
          ),
        ),
      ],
    ),
  );
}
