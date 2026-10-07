import 'package:flutter/material.dart';

Future<String?> showCreateCategoryDialog(BuildContext context) async {
  final name = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая категория'),
        content: TextField(
          controller: name,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Название категории'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, name.text.trim()), child: const Text('Создать')),
        ],
      ),
    ).then((value) => value?.isEmpty == true ? null : value);
  } finally {
    name.dispose();
  }
}
