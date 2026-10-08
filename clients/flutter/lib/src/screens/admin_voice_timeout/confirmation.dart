import 'package:flutter/material.dart';

import 'controller.dart';
import 'button_style.dart';
import '../../widgets/confirmation_dialog.dart';

Future<bool> confirmVoiceTimeout(
  BuildContext context,
  bool lift,
  String name, {
  required AdminVoiceTimeoutController owner,
  Listenable? scopeChanges,
}) async =>
    await showConfirmationDialog<bool>(
      context: context,
      builder: (context) => ListenableBuilder(
        listenable: scopeChanges ?? owner,
        builder: (context, _) => AlertDialog(
          title: Text(
            !owner.active
                ? 'Управление недоступно'
                : lift
                ? 'Снять ограничение голоса?'
                : 'Подтвердить ограничение голоса?',
          ),
          content: Text(
            !owner.active
                ? 'Сессия или сервер изменились. Откройте управление заново.'
                : lift
                ? '$name: снятие не возвращает голос и не включает микрофон. Нужен новый Join.'
                : '$name: текущие голосовые подключения будут отозваны. TEXT и DM сохраняются.',
          ),
          actions: [
            TextButton(
              style: voiceTimeoutButtonStyle,
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            if (owner.active)
              FilledButton(
                style: voiceTimeoutButtonStyle,
                onPressed: () => Navigator.pop(context, owner.active),
                child: const Text('Подтвердить'),
              ),
          ],
        ),
      ),
    ) ??
    false;
