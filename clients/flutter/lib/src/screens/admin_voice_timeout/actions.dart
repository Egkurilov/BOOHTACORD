import 'package:flutter/material.dart';

import 'controller.dart';

Future<bool> confirmVoiceTimeout(
  BuildContext context,
  bool lift,
  String name,
) async =>
    await showDialog<bool>(
      context: context,
      useSafeArea: true,
      builder: (context) => AlertDialog(
        title: Text(
          lift
              ? 'Снять ограничение голоса?'
              : 'Подтвердить ограничение голоса?',
        ),
        content: Text(
          lift
              ? '$name: снятие не возвращает голос и не включает микрофон. Нужен новый Join.'
              : '$name: текущие голосовые подключения будут отозваны. TEXT и DM сохраняются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    ) ??
    false;

class VoiceTimeoutActions extends StatelessWidget {
  const VoiceTimeoutActions({
    super.key,
    required this.owner,
    required this.displayName,
    required this.onClose,
  });
  final AdminVoiceTimeoutController owner;
  final String displayName;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton(
        onPressed: !owner.canMutate
            ? null
            : () async {
                if (await confirmVoiceTimeout(context, false, displayName)) {
                  await owner.apply();
                }
              },
        child: const Text('Ограничить голос'),
      ),
      if (owner.active && owner.value?.active == true)
        OutlinedButton(
          onPressed: !owner.canMutate
              ? null
              : () async {
                  if (await confirmVoiceTimeout(context, true, displayName)) {
                    await owner.clear();
                  }
                },
          child: const Text('Снять ограничение'),
        ),
      TextButton(
        onPressed: owner.active && !owner.busy ? owner.load : null,
        child: const Text('Обновить состояние'),
      ),
      TextButton(
        onPressed: owner.active && owner.busy ? null : onClose,
        child: const Text('Закрыть'),
      ),
    ],
  );
}
