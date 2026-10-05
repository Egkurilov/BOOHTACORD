import 'package:flutter/material.dart';

class CompactMessageComposerActions extends StatelessWidget {
  const CompactMessageComposerActions({
    super.key,
    required this.enabled,
    required this.onAttach,
    required this.onPaste,
    required this.onMention,
    required this.onEmoji,
  });

  final bool enabled;
  final VoidCallback onAttach;
  final VoidCallback onPaste;
  final VoidCallback onMention;
  final VoidCallback onEmoji;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_ComposerAction>(
    tooltip: 'Действия редактора',
    padding: EdgeInsets.zero,
    enabled: enabled,
    onSelected: (action) {
      switch (action) {
        case _ComposerAction.attach:
          onAttach();
        case _ComposerAction.paste:
          onPaste();
        case _ComposerAction.mention:
          onMention();
        case _ComposerAction.emoji:
          onEmoji();
      }
    },
    itemBuilder: (context) => const [
      PopupMenuItem(
        value: _ComposerAction.attach,
        height: 44,
        child: _ComposerActionLabel(
          icon: Icons.attach_file,
          label: 'Прикрепить файл',
        ),
      ),
      PopupMenuItem(
        value: _ComposerAction.paste,
        height: 44,
        child: _ComposerActionLabel(
          icon: Icons.content_paste,
          label: 'Вставить из буфера',
        ),
      ),
      PopupMenuItem(
        value: _ComposerAction.mention,
        height: 44,
        child: _ComposerActionLabel(
          icon: Icons.alternate_email,
          label: 'Упомянуть',
        ),
      ),
      PopupMenuItem(
        value: _ComposerAction.emoji,
        height: 44,
        child: _ComposerActionLabel(
          icon: Icons.emoji_emotions_outlined,
          label: 'Emoji',
        ),
      ),
    ],
    child: const SizedBox(
      width: 44,
      height: 48,
      child: Icon(Icons.add_circle_outline),
    ),
  );
}

enum _ComposerAction { attach, paste, mention, emoji }

class _ComposerActionLabel extends StatelessWidget {
  const _ComposerActionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}
