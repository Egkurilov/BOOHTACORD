import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension PinnedScreenMiniPlayerHeaderControlsRenderer
    on WorkspacePinnedScreenMiniPlayerContext {
  SizedBox renderPinnedScreenMiniPlayerHeaderControls(
    String name,
    bool hasAudio,
    RemoteParticipant? participant,
    int? screenVolume,
  ) => SizedBox(
    height: 44,
    child: Row(
      children: [
        const SizedBox(width: 12),
        const Icon(Icons.monitor_outlined, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GcColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          tooltip: 'К голосу',
          visualDensity: VisualDensity.compact,
          onPressed: onReturnToVoice,
          icon: const Icon(Icons.graphic_eq_outlined, size: 18),
        ),
        if (hasAudio && participant != null)
          IconButton(
            tooltip:
                state.screenShareAudioMuted(participant) || screenVolume == 0
                ? 'Включить звук'
                : 'Выключить звук',
            visualDensity: VisualDensity.compact,
            onPressed: state.deafened
                ? null
                : () => unawaited(state.toggleScreenShareAudio(participant)),
            icon: Icon(
              state.deafened ||
                      state.screenShareAudioMuted(participant) ||
                      screenVolume == 0
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
              size: 18,
            ),
          ),
        IconButton(
          tooltip: 'Остановить просмотр',
          visualDensity: VisualDensity.compact,
          onPressed: onStopWatching,
          icon: const Icon(Icons.close, size: 18),
        ),
        const SizedBox(width: 4),
      ],
    ),
  );
}
