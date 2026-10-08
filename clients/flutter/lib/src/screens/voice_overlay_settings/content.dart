import 'package:flutter/material.dart';

import 'component.dart';
import 'dimensions.dart';
import 'hotkey.dart';
import 'placement.dart';

Widget renderOverlaySettings(OverlaySettingsView view) => AlertDialog(
  title: const Text('Панель говорящих'),
  content: SizedBox(
    width: 420,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            title: const Text('Включить overlay'),
            value: view.draft.enabled,
            onChanged: view.saving
                ? null
                : (v) => view.change(view.draft.copyWith(enabled: v)),
          ),
          const Text(
            'Настройки сохраняются для текущего аккаунта. Панель работает только с текущим голосовым каналом.',
          ),
          const SizedBox(height: 12),
          overlayDimensions(view),
          overlayPlacement(view),
          overlayHotkey(view),
          const SizedBox(height: 12),
          const Text(
            'Перемещение: выберите «Переместить панель» в меню overlay, затем перетащите её. Завершите перемещение в том же меню.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Оконный и безрамочный режимы. Exclusive fullscreen и совместимость с anti-cheat зависят от игры и требуют проверки.',
          ),
          if (view.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Semantics(liveRegion: true, child: Text(view.error!)),
            ),
        ],
      ),
    ),
  ),
  actions: [
    TextButton(
      onPressed: view.saving ? null : () => Navigator.pop(view.context),
      child: const Text('Отмена'),
    ),
    FilledButton(
      key: const ValueKey('save-overlay-settings'),
      onPressed: view.saving ? null : view.submit,
      child: Text(view.saving ? 'Сохраняем…' : 'Сохранить'),
    ),
  ],
);
