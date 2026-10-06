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
    this.desktopLayout = false,
  });
  final String label;
  final VoiceShortcutBinding? binding;
  final bool capturing;
  final bool desktopLayout;
  final VoidCallback onAssign, onClear, onCancel;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: desktopLayout
        ? Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  formatVoiceShortcut(binding),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              _assignButton(),
              if (binding != null) _clearButton(),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$label · ${formatVoiceShortcut(binding)}'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _assignButton(),
                  if (binding != null) _clearButton(),
                ],
              ),
            ],
          ),
  );

  Widget _assignButton() => Focus(
    onFocusChange: (focused) {
      if (!focused && capturing) onCancel();
    },
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
      onPressed: onAssign,
      child: Text(capturing ? 'Нажмите сочетание…' : 'Назначить'),
    ),
  );

  Widget _clearButton() => TextButton(
    style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
    onPressed: onClear,
    child: const Text('Очистить'),
  );
}
