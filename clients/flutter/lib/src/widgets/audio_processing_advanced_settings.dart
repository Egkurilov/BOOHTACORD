import 'package:flutter/material.dart';

import '../features/voice/audio_diagnostics/model.dart';
import '../services/audio_preferences.dart';
import '../services/native_noise_suppression.dart';
import 'noise_suppression_settings.dart';
import 'participant_volume/reset.dart';
import 'voice_audio_diagnostics/control.dart';

/// Less frequently changed audio controls, kept out of the primary settings flow.
class AudioProcessingAdvancedSettings extends StatelessWidget {
  const AudioProcessingAdvancedSettings({
    super.key,
    required this.processing,
    required this.runtime,
    required this.onProcessingChanged,
    required this.voiceConnected,
    required this.voiceDiagnostics,
    required this.resetVolumes,
    this.volumeWarning,
  });

  final AudioProcessingPreferences processing;
  final NativeNoiseSuppressionState runtime;
  final Future<void> Function(AudioProcessingPreferences) onProcessingChanged;
  final bool voiceConnected;
  final VoiceAudioDiagnostics? voiceDiagnostics;
  final Future<void> Function() resetVolumes;
  final String? volumeWarning;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const ValueKey('audio-processing-advanced'),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
    title: const Text('Расширенные настройки и диагностика'),
    subtitle: const Text('Шумоподавление, состояние обработки и статистика'),
    children: [
      NoiseSuppressionSettings(
        processing: processing,
        runtime: runtime,
        onChanged: onProcessingChanged,
      ),
      const SizedBox(height: 8),
      const Text(
        'Нативный SDK не сообщает, какие эффекты фактически применены устройством.',
      ),
      const Divider(height: 24),
      VoiceAudioDiagnosticsControl(
        connected: voiceConnected,
        diagnostics: voiceDiagnostics,
      ),
      AudioVolumeReset(reset: resetVolumes, warning: volumeWarning),
    ],
  );
}
