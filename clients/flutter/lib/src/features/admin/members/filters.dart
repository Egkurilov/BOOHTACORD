import 'package:flutter/material.dart';

import '../layout/width_class.dart';
import '../../../theme.dart';

class AdminMembersFilters extends StatelessWidget {
  const AdminMembersFilters({
    super.key,
    required this.search,
    required this.role,
    required this.onRoleChanged,
  });
  final TextEditingController search;
  final String role;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final narrow = adminWidthClassFor(constraints.maxWidth).isNarrow;
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: GcLayout.fieldHeight,
                child: Semantics(
                  label: 'Поиск участников',
                  child: TextField(
                    key: const ValueKey('admin-member-search'),
                    controller: search,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по имени или логину',
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: narrow ? 81 : 121,
              height: GcLayout.fieldHeight,
              child: DropdownButtonFormField<String>(
                key: const ValueKey('admin-member-role-filter'),
                initialValue: role,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Все роли')),
                  DropdownMenuItem(value: 'MEMBER', child: Text('Пользователь')),
                  DropdownMenuItem(value: 'ADMINISTRATOR', child: Text('Администратор')),
                ],
                selectedItemBuilder: (_) => narrow
                    ? const [Text('Все'), Text('Участ.'), Text('Админ.')]
                    : const [Text('Все роли'), Text('Пользователь'), Text('Администратор')],
                onChanged: (value) { if (value != null) onRoleChanged(value); },
              ),
            ),
          ],
        ),
      );
    },
  );
}
