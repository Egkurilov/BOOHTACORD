import '../../native_bindings.dart';

abstract class WorkspaceAudioSettingsScreenContext extends StatelessWidget {
  const WorkspaceAudioSettingsScreenContext({
    super.key,
    required this.state,
    required this.onBack,
    required this.onCapturePttKey,
    required this.capturingPttKey,
    this.onCaptureVoiceShortcut,
    this.capturingVoiceShortcut,
    this.hardwareKeyboardAvailable = false,
  });
  final AppState state;
  final VoidCallback onBack;
  final VoidCallback? onCapturePttKey;
  final bool capturingPttKey;
  final ValueChanged<String>? onCaptureVoiceShortcut;
  final String? capturingVoiceShortcut;
  final bool hardwareKeyboardAvailable;
}
