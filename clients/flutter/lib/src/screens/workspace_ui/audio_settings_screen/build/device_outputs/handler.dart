import '../../../audio_device_dropdown/component.dart';
import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension AudioSettingsScreenDeviceOutputsRenderer
    on WorkspaceAudioSettingsScreenContext {
  Row renderAudioSettingsScreenDeviceOutputs() => Row(
    children: [
      Expanded(
        child: WorkspaceAudioDeviceDropdown(
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
      ),
      const SizedBox(width: 16),
      Expanded(
        child: WorkspaceAudioDeviceDropdown(
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
      ),
    ],
  );
}
