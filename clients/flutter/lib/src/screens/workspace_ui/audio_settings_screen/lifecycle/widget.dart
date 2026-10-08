import 'context.dart';
import '../handler_bindings.dart';

class WorkspaceAudioSettingsScreen extends WorkspaceAudioSettingsScreenContext
    with WorkspaceAudioSettingsScreenBuildBinding {
  const WorkspaceAudioSettingsScreen({
    super.key,
    required super.state,
    required super.onBack,
    required super.onCapturePttKey,
    required super.capturingPttKey,
    super.onCaptureVoiceShortcut,
    super.capturingVoiceShortcut,
    super.hardwareKeyboardAvailable = false,
  });
}
