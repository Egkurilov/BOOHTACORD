import 'package:flutter/material.dart';

import '../../features/voice/shortcuts/model.dart';

class VoiceShortcutRow extends StatelessWidget {
  const VoiceShortcutRow({
    super.key,
    required this.label,
    required this.binding,
    required this.capturing,
    required this.onAssign,
    required this.onClear,
    required this.onCancel,
  });
  final String label;
  final VoiceShortcutBinding? binding;
  final bool capturing;
  final VoidCallback onAssign, onClear, onCancel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label · ${formatVoiceShortcut(binding)}'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Focus(
              onFocusChange: (focused) {
                if (!focused && capturing) onCancel();
              },
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                ),
                onPressed: onAssign,
                child: Text(capturing ? 'Нажмите сочетание…' : 'Назначить'),
              ),
            ),
            if (binding != null)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                onPressed: onClear,
                child: const Text('Очистить'),
              ),
          ],
        ),
      ],
    ),
  );
}
