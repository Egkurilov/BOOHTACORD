import 'package:flutter/material.dart';

import 'controller.dart';
import 'form.dart';
import 'status.dart';
import 'actions.dart';

class VoiceTimeoutSurface extends StatelessWidget {
  const VoiceTimeoutSurface({
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: owner,
    builder: (context, _) => PopScope(
      canPop: !owner.active || !owner.busy,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ограничение голоса',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (owner.active) Text(displayName),
                const SizedBox(height: 16),
                if (!owner.active)
                  const Text(
                    'Сессия или сервер изменились. Откройте управление заново.',
                  ),
                if (owner.active && owner.busy) const LinearProgressIndicator(),
                if (owner.active && owner.error != null)
                  Semantics(liveRegion: true, child: Text(owner.error!)),
                if (owner.active && owner.value != null)
                  VoiceTimeoutStatus(value: owner.value!),
                if (owner.active) ...[
                  const SizedBox(height: 16),
                  VoiceTimeoutForm(key: ValueKey(owner), owner: owner),
                ],
                const SizedBox(height: 16),
                VoiceTimeoutActions(
                  owner: owner,
                  displayName: displayName,
                  onClose: onClose,
                  scopeChanges: scopeChanges,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
