import 'package:flutter/material.dart';

import 'controller.dart';
import 'confirmation.dart';

class VoiceTimeoutActions extends StatelessWidget {
  const VoiceTimeoutActions({
    super.key,
    required this.owner,
    required this.displayName,
    required this.onClose,
    this.scopeChanges,
  });
  final AdminVoiceTimeoutController owner;
  final String displayName;
  final VoidCallback onClose;
  final Listenable? scopeChanges;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      FilledButton(
        onPressed: !owner.canMutate
            ? null
            : () async {
                if (await confirmVoiceTimeout(
                  context,
                  false,
                  displayName,
                  owner: owner,
                  scopeChanges: scopeChanges,
                )) {
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
                  if (await confirmVoiceTimeout(
                    context,
                    true,
                    displayName,
                    owner: owner,
                    scopeChanges: scopeChanges,
                  )) {
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
