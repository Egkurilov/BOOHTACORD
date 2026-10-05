import 'dart:math' as math;

import 'package:flutter/material.dart';

Future<Set<String>?> showMessageMentionDialog({
  required BuildContext context,
  required List<(String, String)> options,
  required String selfId,
  required Set<String> selectedIds,
}) => showDialog<Set<String>>(
  context: context,
  builder: (context) => _MessageMentionDialog(
    options: options.where((option) => option.$1 != selfId).toList(),
    selectedIds: selectedIds,
  ),
);

class _MessageMentionDialog extends StatefulWidget {
  const _MessageMentionDialog({
    required this.options,
    required this.selectedIds,
  });

  final List<(String, String)> options;
  final Set<String> selectedIds;

  @override
  State<_MessageMentionDialog> createState() => _MessageMentionDialogState();
}

class _MessageMentionDialogState extends State<_MessageMentionDialog> {
  late final Set<String> _selectedIds = Set<String>.from(widget.selectedIds);

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(400.0, viewport.width - 48);
    final height = math.min(420.0, viewport.height * 0.55);
    return AlertDialog(
      title: const Text('Упомянуть'),
      content: SizedBox(
        width: width,
        height: height,
        child: widget.options.isEmpty
            ? const Center(child: Text('Некого упомянуть'))
            : ListView.builder(
                itemCount: widget.options.length,
                itemBuilder: (context, index) {
                  final (id, name) = widget.options[index];
                  final selected = _selectedIds.contains(id);
                  final limitReached = _selectedIds.length >= 100;
                  return CheckboxListTile(
                    value: selected,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: !selected && limitReached
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selectedIds.add(id);
                              } else {
                                _selectedIds.remove(id);
                              }
                            });
                          },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, Set<String>.from(_selectedIds)),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}
