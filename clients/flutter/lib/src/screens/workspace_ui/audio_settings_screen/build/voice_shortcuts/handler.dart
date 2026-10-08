import '../../../audio_settings_card/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension AudioSettingsScreenVoiceShortcutsRenderer
    on WorkspaceAudioSettingsScreenContext {
  WorkspaceAudioSettingsCard renderAudioSettingsScreenVoiceShortcuts(
    bool compact,
  ) => WorkspaceAudioSettingsCard(
    cardKey: const ValueKey('audio-settings-shortcuts-card'),
    title: 'Быстрые клавиши',
    subtitle: 'Назначьте сочетания для микрофона и выключения звука. Они работают только в активном окне.',
    compact: compact,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VoiceShortcutRow(
          label: 'Микрофон',
          desktopLayout: !compact,
          binding: state.microphoneShortcut,
          capturing: capturingVoiceShortcut == 'microphone',
          onAssign: () => onCaptureVoiceShortcut?.call('microphone'),
          onCancel: () => onCaptureVoiceShortcut?.call(''),
          onClear: () => unawaited(state.setVoiceShortcut('microphone', null)),
        ),
        VoiceShortcutRow(
          label: 'Выключить звук',
          desktopLayout: !compact,
          binding: state.deafenShortcut,
          capturing: capturingVoiceShortcut == 'deafen',
          onAssign: () => onCaptureVoiceShortcut?.call('deafen'),
          onCancel: () => onCaptureVoiceShortcut?.call(''),
          onClear: () => unawaited(state.setVoiceShortcut('deafen', null)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              onCaptureVoiceShortcut?.call('');
              unawaited(state.voice.resetVoiceShortcuts());
            },
            child: const Text('Сбросить сочетания'),
          ),
        ),
      ],
    ),
  );
}
