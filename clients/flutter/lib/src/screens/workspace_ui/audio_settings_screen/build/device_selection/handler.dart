import '../semantics_column_workspace_audio_settings_card/handler.dart';
import '../device_outputs/handler.dart';
import '../../../audio_device_dropdown/component.dart';
import '../../../audio_settings_card/component.dart';
import '../../../error_banner/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension AudioSettingsScreenDeviceSelectionRenderer
    on WorkspaceAudioSettingsScreenContext {
  WorkspaceAudioSettingsCard renderAudioSettingsScreenDeviceSelection(
    bool compact,
    MediaDevice? inputDevice,
    MediaDevice? outputDevice,
  ) => WorkspaceAudioSettingsCard(
    cardKey: const ValueKey('audio-settings-device-card'),
    title: 'Устройства',
    subtitle: 'Настройки действуют на этом устройстве.',
    compact: compact,
    minHeight: compact ? 346 : 282,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AudioDeviceScanNotice(
          status: state.audioDeviceScanStatus,
          failure: state.audioDeviceScanFailure,
          inputCount: state.audioInputDevices.length,
          outputCount: state.audioOutputDevices.length,
        ),
        if (compact) ...[
          WorkspaceAudioDeviceDropdown(
            label: 'Микрофон',
            devices: state.audioInputDevices,
            selectedId: state.selectedAudioInputId,
            switching: state.audioInputSwitching,
            emptyLabel: state.audioDevicesLoading
                ? 'Ищем устройства…'
                : state.audioDeviceScanFailed
                ? 'Список недоступен'
                : 'Микрофоны не найдены',
            onChanged: state.selectAudioInput,
          ),
          const SizedBox(height: 12),
          WorkspaceAudioDeviceDropdown(
            label: 'Динамик',
            devices: state.audioOutputDevices,
            selectedId: state.selectedAudioOutputId,
            switching: state.audioOutputSwitching,
            emptyLabel: state.audioDevicesLoading
                ? 'Ищем устройства…'
                : state.audioDeviceScanFailed
                ? 'Список недоступен'
                : 'Динамики не найдены',
            onChanged: state.selectAudioOutput,
          ),
        ] else
          renderAudioSettingsScreenDeviceOutputs(),
        if (state.audioDeviceWarning != null) ...[
          const SizedBox(height: 12),
          renderAudioSettingsScreenSemanticsColumnWorkspaceAudioSettingsCard(),
        ],
        if (!state.audioDevicesLoading && !state.audioDeviceScanFailed) ...[
          if (state.voiceChannel == null) ...[
            const SizedBox(height: 12),
            const Text(
              'До подключения выбор устройства используется для локальной проверки; устройство звонка можно переключить после входа.',
              style: TextStyle(color: GcColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          AudioDeviceCheck(
            key: const ValueKey('audio-device-check'),
            inputDeviceId: inputDevice?.deviceId,
            inputDeviceLabel: inputDevice?.label,
            outputDeviceId: outputDevice?.deviceId,
            outputDeviceLabel: outputDevice?.label,
          ),
        ],
        if (state.audioSettingsError != null &&
            state.audioDeviceScanFailure == null) ...[
          const SizedBox(height: 12),
          WorkspaceErrorBanner(message: state.audioSettingsError!),
        ],
      ],
    ),
  );
}
