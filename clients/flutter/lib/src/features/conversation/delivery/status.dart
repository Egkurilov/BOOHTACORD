import 'package:flutter/material.dart';

import '../../../models.dart';

class DeliveryStatus extends StatelessWidget {
  const DeliveryStatus({
    super.key,
    required this.status,
    this.busy = false,
    this.retryBlocked = false,
    this.onRetry,
    this.onDiscard,
  });
  final MessageSendStatus? status;
  final bool busy, retryBlocked;
  final VoidCallback? onRetry, onDiscard;
  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    if (status != MessageSendStatus.failed) {
      return Semantics(
        liveRegion: true,
        child: Text(
          status == MessageSendStatus.checking
              ? 'Проверяем доставку…'
              : 'Отправляется…',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(liveRegion: true, child: const Text('Не отправлено')),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: busy || retryBlocked ? null : onRetry,
              child: const Text('Повторить отправку'),
            ),
            TextButton(
              onPressed: busy ? null : onDiscard,
              child: const Text('Убрать из очереди'),
            ),
          ],
        ),
        if (retryBlocked)
          const Text('Исправьте сообщение или доступ перед новой отправкой.'),
      ],
    );
  }
}
