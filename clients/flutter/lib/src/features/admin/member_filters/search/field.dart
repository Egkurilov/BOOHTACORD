import 'package:flutter/material.dart';

class AdminMemberSearch extends StatelessWidget {
  const AdminMemberSearch({
    super.key,
    required this.search,
    required this.onSearchChanged,
  });
  final TextEditingController search;
  final VoidCallback onSearchChanged;
  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: 44,
        maxHeight: MediaQuery.textScalerOf(context).scale(1) <= 1
            ? 44
            : double.infinity,
      ),
      child: Semantics(
        label: 'Поиск участников по имени или логину',
        child: TextField(
          key: const ValueKey('admin-member-search'),
          controller: search,
          onChanged: (_) => onSearchChanged(),
          decoration: InputDecoration(
            hintText: largeText ? 'Поиск' : 'Поиск по имени или логину',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
          ),
        ),
      ),
    );
  }
}
