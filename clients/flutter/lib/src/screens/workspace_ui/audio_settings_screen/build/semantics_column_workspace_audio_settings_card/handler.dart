import '../../../native_bindings.dart';
import '../../lifecycle/context.dart';

extension AudioSettingsScreenSemanticsColumnWorkspaceAudioSettingsCardRenderer
    on WorkspaceAudioSettingsScreenContext {
  Semantics
  renderAudioSettingsScreenSemanticsColumnWorkspaceAudioSettingsCard() =>
      Semantics(
        key: const ValueKey('audio-device-warning'),
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              size: 16,
              color: GcColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.audioDeviceWarning!,
                style: const TextStyle(color: GcColors.warning, fontSize: 12),
              ),
            ),
          ],
        ),
      );
}
