import 'package:flutter/material.dart';

import 'component.dart';

Widget overlayPlacement(OverlaySettingsView view) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: DropdownButtonFormField<String>(
    initialValue: 'saved',
    decoration: const InputDecoration(labelText: 'Положение на мониторе'),
    items: const [
      DropdownMenuItem(value: 'saved', child: Text('Сохранённое положение')),
      DropdownMenuItem(value: 'top-left', child: Text('Слева вверху')),
      DropdownMenuItem(value: 'top-right', child: Text('Справа вверху')),
      DropdownMenuItem(value: 'bottom-left', child: Text('Слева внизу')),
      DropdownMenuItem(value: 'bottom-right', child: Text('Справа внизу')),
    ],
    onChanged: view.saving
        ? null
        : (value) {
            if (value == null || value == 'saved') return;
            view.change(
              view.draft.copyWith(
                x: value.endsWith('right') ? 1 : 0,
                y: value.startsWith('bottom') ? 1 : 0,
              ),
            );
          },
  ),
);
