import 'package:flutter/material.dart';

import '../../../theme.dart';

class PasswordGenerationControls extends StatelessWidget {
  const PasswordGenerationControls({
    super.key,
    required this.pending,
    required this.confirm,
    required this.status,
    required this.onGenerate,
    required this.onReplace,
    required this.onKeep,
  });
  final bool pending;
  final bool confirm;
  final String? status;
  final VoidCallback onGenerate;
  final VoidCallback onReplace;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const ValueKey('auth-generate-password'),
        onPressed: pending ? null : onGenerate,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Сгенерировать пароль'),
      ),
      if (confirm) ...[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: const Text(
            'Заменить введённый пароль сгенерированным?',
            style: TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: pending ? null : onReplace,
              child: const Text('Заменить'),
            ),
            TextButton(
              onPressed: pending ? null : onKeep,
              child: const Text('Оставить'),
            ),
          ],
        ),
      ],
      if (status != null)
        Semantics(
          liveRegion: true,
          child: Text(
            status!,
            style: const TextStyle(color: GcColors.muted, fontSize: 12),
          ),
        ),
    ],
  );
}
