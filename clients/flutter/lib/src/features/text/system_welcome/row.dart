import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';

class SystemWelcomeMessage extends StatelessWidget {
  const SystemWelcomeMessage({
    super.key,
    required this.message,
    required this.displayName,
    this.onDelete,
  });
  final ChatMessage message;
  final String displayName;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Системное приветствие',
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 18,
            color: GcColors.muted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: message.deleted
                ? const Text('Системное приветствие удалено.')
                : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '@$displayName ',
                          style: const TextStyle(color: GcColors.accent),
                        ),
                        TextSpan(text: message.body),
                      ],
                    ),
                  ),
          ),
          if (!message.deleted && onDelete != null)
            IconButton(
              tooltip: 'Удалить системное приветствие',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    ),
  );
}
