import 'package:flutter/material.dart';

import '../../features/admin/voice_timeout/model.dart';

class VoiceTimeoutStatus extends StatelessWidget {
  const VoiceTimeoutStatus({super.key, required this.value});
  final VoiceTimeoutState value;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.active
              ? 'Голос ограничен до ${value.expiresAt!.toIso8601String()} (UTC).'
              : 'Ограничение не активно.',
        ),
        if (value.active) Text('Причина: ${value.reason!.label}'),
        Text('Отключено логических подключений: ${value.revokedLeases}'),
        if (value.revocationPending)
          const Text(
            'Отключение медиа ожидает подтверждения. Сервер продолжает попытки.',
          ),
        const Text(
          'TEXT и DM доступны. После снятия нужно новое подключение вручную; микрофон автоматически не включается.',
        ),
      ],
    ),
  );
}
