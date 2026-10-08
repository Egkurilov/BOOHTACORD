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
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      minHeight: 44,
      maxHeight: MediaQuery.textScalerOf(context).scale(1) <= 1
          ? 44
          : double.infinity,
    ),
    child: Semantics(
      label: 'Поиск участников',
      child: TextField(
        key: const ValueKey('admin-member-search'),
        controller: search,
        onChanged: (_) => onSearchChanged(),
        decoration: const InputDecoration(
          hintText: 'Поиск по имени или логину',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
      ),
    ),
  );
}
