import 'package:flutter/material.dart';

class AdminMemberStatusFilter extends StatelessWidget {
  const AdminMemberStatusFilter({
    super.key,
    required this.status,
    required this.onStatusChanged,
  });

  final String status;
  final ValueChanged<String> onStatusChanged;

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
        width: compact || largeText ? double.infinity : 146,
        child: Semantics(
          label: 'Фильтр по статусу',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('admin-member-status-filter'),
            initialValue: status,
            isExpanded: true,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontSize: 14),
            selectedItemBuilder: (_) => compact && !largeText
                ? const [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Любой', maxLines: 1, softWrap: false),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Активен', maxLines: 1, softWrap: false),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Блокир.', maxLines: 1, softWrap: false),
                    ),
                  ]
                : const [
                    Text('Любой статус'),
                    Text('Активен'),
                    Text('Заблокирован'),
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
                child: Text('Любой статус', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: 'ACTIVE',
                child: Text('Активен', overflow: TextOverflow.ellipsis),
              ),
              DropdownMenuItem(
                value: 'BLOCKED',
                child: Text('Заблокирован', overflow: TextOverflow.ellipsis),
              ),
            ],
            onChanged: (value) {
              if (value != null) onStatusChanged(value);
            },
          ),
        ),
      ),
    );
  }
}
