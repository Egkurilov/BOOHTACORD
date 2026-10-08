import 'package:flutter/material.dart';

import 'component.dart';

Widget overlayDimensions(OverlaySettingsView view) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Масштаб: ${(view.draft.scale * 100).round()}%'),
    Slider(
      key: const ValueKey('overlay-scale'),
      value: view.draft.scale,
      min: .75,
      max: 2,
      divisions: 25,
      label: '${(view.draft.scale * 100).round()}%',
      onChanged: view.saving
          ? null
          : (v) => view.change(view.draft.copyWith(scale: v)),
    ),
    Text('Непрозрачность: ${(view.draft.opacity * 100).round()}%'),
    Slider(
      key: const ValueKey('overlay-opacity'),
      value: view.draft.opacity,
      min: .25,
      max: 1,
      divisions: 15,
      label: '${(view.draft.opacity * 100).round()}%',
      onChanged: view.saving
          ? null
          : (v) => view.change(view.draft.copyWith(opacity: v)),
    ),
    DropdownButtonFormField<int>(
      initialValue: view.draft.maxParticipants,
      decoration: const InputDecoration(labelText: 'Максимум участников'),
      items: [
        for (var count = 1; count <= 12; count++)
          DropdownMenuItem(value: count, child: Text('$count')),
      ],
      onChanged: view.saving
          ? null
          : (v) {
              if (v != null) {
                view.change(view.draft.copyWith(maxParticipants: v));
              }
            },
    ),
  ],
);
