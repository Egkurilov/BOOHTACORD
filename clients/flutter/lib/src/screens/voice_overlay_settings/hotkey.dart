import 'package:flutter/material.dart';

import 'component.dart';

String overlayModifiers(int flags) => [
  if (flags & 2 != 0) 'Ctrl',
  if (flags & 4 != 0) 'Shift',
  if (flags & 1 != 0) 'Alt',
  if (flags & 8 != 0) 'Win',
].join(' + ');
Widget overlayHotkey(OverlaySettingsView view) => Column(
  children: [
    const SizedBox(height: 12),
    DropdownButtonFormField<int>(
      initialValue: view.draft.hotkey,
      decoration: const InputDecoration(
        labelText: 'Горячая клавиша показа / скрытия',
      ),
      items: [
        const DropdownMenuItem(value: 0, child: Text('Не использовать')),
        for (var key = 112; key <= 123; key++)
          DropdownMenuItem(value: key, child: Text('F${key - 111}')),
      ],
      onChanged: view.saving
          ? null
          : (v) {
              if (v != null) view.change(view.draft.copyWith(hotkey: v));
            },
    ),
    DropdownButtonFormField<int>(
      initialValue: view.draft.modifiers,
      decoration: const InputDecoration(labelText: 'Модификаторы'),
      items: [
        for (var flags = 1; flags <= 15; flags++)
          DropdownMenuItem(value: flags, child: Text(overlayModifiers(flags))),
      ],
      onChanged: view.saving
          ? null
          : (v) {
              if (v != null) view.change(view.draft.copyWith(modifiers: v));
            },
    ),
  ],
);
