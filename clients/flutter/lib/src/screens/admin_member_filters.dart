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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: Semantics(
                label: 'Поиск участников',
                child: TextField(
                  key: const ValueKey('admin-member-search'),
                  controller: search,
                  onChanged: (_) => onSearchChanged(),
                  decoration: const InputDecoration(
                    hintText: 'Поиск по имени или логину',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: compact ? 81 : 121,
            height: 44,
            child: Semantics(
              label: 'Фильтр по роли',
              child: DropdownButtonFormField<String>(
                key: const ValueKey('admin-member-role-filter'),
                initialValue: role,
                isExpanded: true,
                style: const TextStyle(fontSize: 14),
                selectedItemBuilder: (_) => compact
                    ? const [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Все', maxLines: 1, softWrap: false),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Участ.', maxLines: 1, softWrap: false),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('Админ.', maxLines: 1, softWrap: false),
                        ),
                      ]
                    : const [
                        Text('Все роли'),
                        Text('Пользователь'),
                        Text('Администратор'),
                      ],
                icon: compact
                    ? const SizedBox.shrink()
                    : const Icon(Icons.arrow_drop_down),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 12,
                    vertical: 11,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('Все роли', overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'MEMBER',
                    child: Text(
                      'Пользователь',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'ADMINISTRATOR',
                    child: Text(
                      'Администратор',
                      overflow: TextOverflow.ellipsis,
                    ),
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
}
