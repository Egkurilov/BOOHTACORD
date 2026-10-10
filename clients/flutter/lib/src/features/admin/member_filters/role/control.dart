import 'package:flutter/material.dart';

class AdminMemberRoleFilter extends StatelessWidget {
  const AdminMemberRoleFilter({
    super.key,
    required this.role,
    required this.onRoleChanged,
  });
  final String role;
  final ValueChanged<String> onRoleChanged;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width <= 720;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 44,
        maxHeight: MediaQuery.textScalerOf(context).scale(1) <= 1
            ? 44
            : double.infinity,
      ),
      child: SizedBox(
        width: compact
            ? double.infinity
            : largeText
            ? double.infinity
            : 121,
        child: Semantics(
          label: 'Фильтр по роли',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('admin-member-role-filter'),
            initialValue: role,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 14),
            selectedItemBuilder: (_) => compact && !largeText
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
    );
  }
}
