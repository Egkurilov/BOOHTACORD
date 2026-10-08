import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension VoiceParticipantCardParticipantDetailsRenderer
    on WorkspaceVoiceParticipantCardContext {
  Column renderVoiceParticipantCardParticipantDetails(
    VoiceParticipantPresentation presentation,
  ) => Column(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      AuthenticatedAvatar(
        state: state,
        name: name,
        avatarUrl: avatarUrl,
        radius: 32,
        fallbackFontSize: 26,
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              isLocal ? '$name (вы)' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 7),
          Icon(
            deafened
                ? Icons.headset_off
                : muted || microphoneUnavailable
                ? Icons.mic_off
                : presentation.isSpeaking
                ? Icons.graphic_eq
                : Icons.mic,
            size: 16,
            color: deafened
                ? GcColors.danger
                : microphoneUnavailable
                ? GcColors.warning
                : muted
                ? GcColors.danger
                : GcColors.textSecondary,
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        height: 16,
        child: Text(
          presentation.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: presentation.isSpeaking ? GcColors.success : GcColors.muted,
            fontSize: 12,
          ),
        ),
      ),
      if (hasScreen) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          key: const ValueKey('voice-participant-watch-screen'),
          onPressed: onScreenTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: GcColors.accentText,
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Смотреть экран'),
        ),
      ],
    ],
  );
}
