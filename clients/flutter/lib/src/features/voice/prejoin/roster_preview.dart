import 'package:flutter/material.dart';

import '../../../app_state.dart';
import '../../../theme.dart';
import '../roster_state/controller.dart';
import 'member_row.dart';

class VoiceRosterPreview extends StatelessWidget {
  const VoiceRosterPreview({
    super.key,
    required this.state,
    required this.channelId,
  });
  final AppState state;
  final String channelId;
  @override
  Widget build(BuildContext context) {
    final owner = state.voiceRoster;
    final roster = state.voiceRosters
        ?.where((item) => item.channelId == channelId)
        .firstOrNull;
    final unavailable = state.voiceRosterError != null;
    final stale = owner.phase == VoiceRosterPhase.stale && roster != null;
    final expired = owner.phase == VoiceRosterPhase.sessionExpired;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GcColors.raised,
        borderRadius: BorderRadius.circular(GcRadii.md),
        border: Border.all(color: GcColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roster == null || roster.participants.isEmpty
                ? 'Участники голосового канала'
                : '${stale ? 'Последний состав' : 'Сейчас в канале'}: ${roster.participants.length}',
            style: const TextStyle(
              color: GcColors.text,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          if (stale || unavailable || expired)
            Semantics(
              liveRegion: true,
              child: Text(
                expired
                    ? 'Сессия завершена. Войдите снова.'
                    : stale
                    ? 'Состав устарел. Не удалось обновить состав комнаты.'
                    : 'Не удалось обновить состав комнаты.',
                style: const TextStyle(color: GcColors.warning, fontSize: 12),
              ),
            ),
          if (roster == null && !unavailable && !expired)
            Semantics(
              liveRegion: true,
              child: const Text(
                'Проверяем, кто сейчас в комнате…',
                style: TextStyle(color: GcColors.muted, fontSize: 12),
              ),
            )
          else if (roster?.participants.isEmpty == true)
            Text(
              stale ? 'Последний состав был пустым.' : 'Пока никого нет.',
              style: const TextStyle(color: GcColors.muted, fontSize: 13),
            )
          else if (roster != null)
            for (
              var index = 0;
              index < roster.participants.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(height: 8),
              VoiceRosterMemberRow(
                participant: roster.participants[index],
                state: state,
              ),
            ],
          if ((stale || unavailable) && !expired)
            TextButton.icon(
              key: const ValueKey('retry-voice-roster'),
              onPressed: owner.canRetry ? owner.retryVoiceRosters : null,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Повторить попытку'),
            ),
        ],
      ),
    );
  }
}
