import 'package:flutter/material.dart';

class AuditDateFilter extends StatelessWidget {
  const AuditDateFilter({
    super.key,
    required this.date,
    required this.from,
    required this.onChanged,
  });

  final DateTime? date;
  final bool from;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    key: ValueKey(from ? 'admin-audit-from-filter' : 'admin-audit-to-filter'),
    onPressed: () => _pickDate(context),
    child: Text(
      date == null
          ? from ? 'От даты' : 'До даты'
          : '${from ? 'От' : 'До'} ${_formatDay(date!)}',
      overflow: TextOverflow.ellipsis,
    ),
  );

  Future<void> _pickDate(BuildContext context) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDate: date ?? DateTime.now(),
    );
    if (value != null) onChanged(DateTime(value.year, value.month, value.day));
  }
}

String _formatDay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
