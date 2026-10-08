import '../../../show_screen_share_setup/component.dart';
import '../../../voice_dock_button/component.dart';
import '../../../voice_dock_ptt_button/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';
import '../../../../voice_overlay_settings/factory.dart';

extension VoiceDockConnectedControlsRenderer on WorkspaceVoiceDockContext {
  Row renderVoiceDockConnectedControls(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      if (compact &&
          state.usesTouchPushToTalk &&
          state.audioActivationMode == AudioActivationMode.ptt)
        WorkspaceVoiceDockPttButton(state: state)
      else
        WorkspaceVoiceDockButton(
          compact: compact,
          tooltip: state.microphoneUnavailable
              ? 'Микрофон недоступен · повторить включение'
              : state.audioActivationMode == AudioActivationMode.ptt
              ? 'Микрофон управляется push-to-talk'
              : state.microphoneMuted
              ? 'Включить микрофон'
              : 'Выключить микрофон',
          semanticsLabel: state.microphoneMuted
              ? 'Включить микрофон'
              : 'Выключить микрофон',
          icon: state.microphoneMuted ? Icons.mic_off : Icons.mic,
          danger: state.microphoneMuted,
          toggled: !state.microphoneMuted,
          enabled:
              state.audioActivationMode != AudioActivationMode.ptt &&
              !state.deafened,
          onTap: state.toggleMicrophone,
        ),
      WorkspaceVoiceDockButton(
        compact: compact,
        tooltip: state.deafened
            ? 'Включить удалённый звук'
            : 'Выключить удалённый звук',
        icon: state.deafened ? Icons.headset_off : Icons.headphones,
        danger: state.deafened,
        toggled: state.deafened,
        enabled:
            !state.deafenChanging && state.voicePhase != VoicePhase.leaving,
        onTap: state.toggleDeafen,
      ),
      WorkspaceVoiceDockButton(
        compact: compact,
        tooltip: switch (state.screenSharePhase) {
          ScreenSharePhase.starting => 'Запускаем демонстрацию экрана…',
          ScreenSharePhase.stopping => 'Останавливаем демонстрацию…',
          ScreenSharePhase.sharing => 'Остановить демонстрацию экрана',
          _ => 'Начать демонстрацию экрана',
        },
        icon: state.screenSharePhase == ScreenSharePhase.sharing
            ? Icons.stop_screen_share_outlined
            : Icons.screen_share_outlined,
        danger: state.screenSharePhase == ScreenSharePhase.sharing,
        enabled: switch (state.screenSharePhase) {
          ScreenSharePhase.starting || ScreenSharePhase.stopping => false,
          ScreenSharePhase.sharing => state.voicePhase != VoicePhase.leaving,
          _ =>
            state.voicePhase == VoicePhase.connected ||
                state.voicePhase == VoicePhase.listener,
        },
        onTap: state.screenSharePhase == ScreenSharePhase.sharing
            ? state.stopScreenShare
            : () => unawaited(workspaceShowScreenShareSetup(context, state)),
      ),
      WorkspaceVoiceDockButton(
        compact: compact,
        tooltip: state.voiceStreamSoundEnabled
            ? 'Выключить сигнал новых трансляций'
            : 'Включить сигнал новых трансляций',
        semanticsLabel: state.voiceStreamSoundEnabled
            ? 'Звук начала трансляций включён'
            : 'Звук начала трансляций выключен',
        icon: state.voiceStreamSoundEnabled
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        danger: false,
        toggled: state.voiceStreamSoundEnabled,
        onTap: () => unawaited(
          state.setVoiceStreamSoundEnabled(!state.voiceStreamSoundEnabled),
        ),
      ),
      VoiceOverlayToggle(
        onSettings: () => unawaited(showVoiceOverlaySettings(context, state)),
        onEdit: () => unawaited(toggleVoiceOverlayEditing(state)),
        editing:
            state.voiceOverlayWindowsClient?.configuration.editing ?? false,
        enabled: state.voiceOverlay.enabled,
        onlySpeakers: state.voiceOverlay.onlySpeakers,
        available: workspaceConnected,
        onChanged: state.setVoiceOverlayEnabled,
        onOnlySpeakersChanged: (value) =>
            state.setVoiceOverlayOnlySpeakers(value),
      ),
      WorkspaceVoiceDockButton(
        compact: compact,
        tooltip: state.voicePhase == VoicePhase.leaving
            ? 'Выходим…'
            : 'Выйти из голосового канала',
        icon: Icons.call_end,
        danger: true,
        enabled: state.voicePhase != VoicePhase.leaving,
        onTap: state.leaveVoice,
      ),
    ],
  );
}
