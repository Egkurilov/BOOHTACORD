import '../../../audio_activation_selector/component.dart';
import '../../../audio_settings_card/component.dart';
import '../../../error_banner/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension AudioSettingsScreenMicrophoneActivationRenderer
    on WorkspaceAudioSettingsScreenContext {
  WorkspaceAudioSettingsCard renderAudioSettingsScreenMicrophoneActivation(
    bool compact,
  ) => WorkspaceAudioSettingsCard(
    cardKey: const ValueKey('audio-settings-activation-card'),
    title: 'Активация микрофона',
    subtitle: 'Выберите удобный способ общения.',
    compact: compact,
    minHeight: compact ? 152 : 164,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: const ValueKey('audio-activation-mode-group'),
          container: true,
          explicitChildNodes: true,
          label: 'Активация микрофона',
          child: WorkspaceAudioActivationSelector(
            compact: compact,
            value: state.audioActivationMode,
            onChanged: (mode) => unawaited(state.setAudioActivationMode(mode)),
          ),
        ),
        if (!state.usesTouchPushToTalk) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCapturePttKey,
            icon: Icon(
              capturingPttKey ? Icons.keyboard : Icons.keyboard_alt_outlined,
            ),
            label: Text(
              capturingPttKey
                  ? 'Нажмите клавишу… · Esc — отмена'
                  : state.pushToTalkKeyLabel == null
                  ? 'Назначить PTT-клавишу'
                  : 'Клавиша PTT · ${state.pushToTalkKeyLabel}',
            ),
          ),
        ],
        if (state.audioActivationMode == AudioActivationMode.ptt)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              state.usesTouchPushToTalk
                  ? 'Удерживайте кнопку микрофона в панели голосового канала, чтобы говорить. При сворачивании приложения микрофон выключается.'
                  : 'Удерживайте назначенную клавишу, чтобы говорить. При потере фокуса микрофон выключается.',
              style: const TextStyle(color: GcColors.muted, fontSize: 12),
            ),
          ),
        MicrophoneControl(
          settings: state.microphoneSettings,
          runtime: state.microphoneControlsRuntime,
          onChanged: state.updateMicrophoneSettings,
          sensitivity: true,
          vad: state.audioActivationMode == AudioActivationMode.vad,
          agc: state.audioProcessing.autoGainControl,
        ),
        if (state.audioActivationError != null) ...[
          const SizedBox(height: 8),
          WorkspaceErrorBanner(message: state.audioActivationError!),
        ],
      ],
    ),
  );
}
