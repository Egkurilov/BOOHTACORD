import 'package:flutter/material.dart';
import '../../features/audio/preferences/microphone.dart';
import '../../features/audio/microphone_controls/native.dart';
import 'meter.dart';
class MicrophoneControl extends StatelessWidget {
  const MicrophoneControl({super.key, required this.settings, required this.runtime,
    required this.onChanged, required this.sensitivity, required this.vad, required this.agc});
  final MicrophoneSettings settings;
  final NativeMicrophoneControls runtime;
  final Future<void> Function(MicrophoneSettings) onChanged;
  final bool sensitivity, vad, agc;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: runtime,
    builder: (context, _) {
      final unavailable = runtime.status == 'unsupported' || runtime.status == 'error';
      final disabled = unavailable || (sensitivity ? !vad : agc);
      final value = sensitivity ? settings.vadThresholdDb : settings.microphoneGainPercent;
      final unit = sensitivity ? 'dBFS' : '%';
      final label = sensitivity ? 'Чувствительность' : 'Громкость микрофона';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Text('$label: ${value.round()} $unit'),
        Slider(
          key: ValueKey(sensitivity ? 'microphone-vad-threshold' : 'microphone-input-gain'),
          value: value, min: sensitivity ? -70 : 0, max: sensitivity ? -20 : 200,
          divisions: sensitivity ? 50 : 200, label: '${value.round()} $unit',
          semanticFormatterCallback: (v) => '${v.round()} $unit',
          onChanged: disabled ? null : (v) => onChanged(sensitivity
            ? settings.copyWith(vadThresholdDb: v)
            : settings.copyWith(microphoneGainPercent: v)),
        ),
        if (sensitivity) ...[
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Flexible(child: Text('Слышно тихую речь')),
            Flexible(child: Text('Меньше фоновых звуков')),
          ]),
          if (!vad) const Text('В режиме PTT порог не используется.'),
          MicrophoneLevelMeter(levelDb: runtime.levelDb, thresholdDb: settings.vadThresholdDb),
          const Text('Линия — порог. Уровень до усиления доступен при включённом микрофоне в звонке.'),
          Text(switch (runtime.status) {
            'active' => 'Обработка применена к сигналу микрофона.',
            'initializing' => 'Ожидаем обработанные кадры микрофона.',
            'unsupported' => 'Capture processor недоступен для этого формата. Настройки не применены.',
            'error' => 'Не удалось проверить обработку. Применение не подтверждено.',
            _ => 'Микрофон выключен.',
          }),
        ] else ...[
          if (agc) const Text('Управляется автоматически. Ручное значение сохранено.')
          else const Text('Усиление отправляемого сигнала. 100% — без дополнительного усиления.'),
          Semantics(liveRegion: true, child: Text(runtime.clipping
            ? 'Перегрузка: уменьшите громкость микрофона.'
            : 'Перегрузка не обнаружена.')),
        ],
        TextButton(
          onPressed: disabled ? null : () => onChanged(sensitivity
            ? settings.copyWith(vadThresholdDb: -50)
            : settings.copyWith(microphoneGainPercent: 100)),
          child: Text(sensitivity ? 'Сбросить чувствительность' : 'Сбросить громкость'),
        ),
      ]);
    },
  );
}
