import 'package:flutter/material.dart';

import '../../features/audio/preferences/microphone.dart';
import '../../features/audio/microphone_controls/native.dart';
import 'meter.dart';

class MicrophoneControl extends StatelessWidget {
  const MicrophoneControl({
    super.key,
    required this.settings,
    required this.runtime,
    required this.onChanged,
    required this.sensitivity,
    required this.vad,
    required this.agc,
  });
  final MicrophoneSettings settings;
  final NativeMicrophoneControls runtime;
  final Future<void> Function({
    double? vadThresholdDb,
    double? microphoneGainPercent,
  })
  onChanged;
  final bool sensitivity, vad, agc;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: runtime,
    builder: (context, _) {
      final unavailable =
          runtime.status == 'unsupported' || runtime.status == 'error';
      final disabled = unavailable || (sensitivity ? !vad : agc);
      final value = sensitivity
          ? settings.vadThresholdDb
          : settings.microphoneGainPercent;
      final label = sensitivity ? 'Чувствительность' : 'Громкость микрофона';
      final displayedValue = sensitivity
          ? '${value.round()} dBFS'
          : agc
          ? '100%'
          : '${value.round()}%';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text('$label: $displayedValue'),
          Semantics(
            label: label,
            child: Slider(
              key: ValueKey(
                sensitivity
                    ? 'microphone-vad-threshold'
                    : 'microphone-input-gain',
              ),
              value: value,
              min: sensitivity ? -70 : 0,
              max: sensitivity ? -20 : 200,
              divisions: sensitivity ? 50 : 200,
              label: sensitivity
                  ? '${value.round()} dBFS'
                  : '${value.round()}%',
              semanticFormatterCallback: (v) => sensitivity
                  ? '${v.round()} dBFS'
                  : agc
                  ? 'Управляется автоматически'
                  : '${v.round()}%',
              onChanged: disabled
                  ? null
                  : (v) => sensitivity
                        ? onChanged(vadThresholdDb: v)
                        : onChanged(microphoneGainPercent: v),
            ),
          ),
          if (sensitivity) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text('Слышно тихую речь')),
                Flexible(child: Text('Меньше фоновых звуков')),
              ],
            ),
            if (!vad) const Text('В режиме PTT порог не используется.'),
            MicrophoneLevelMeter(
              levelDb: runtime.levelDb,
              thresholdDb: settings.vadThresholdDb,
            ),
            const Text(
              'Линия — порог. Уровень до усиления доступен при включённом микрофоне в звонке.',
            ),
            Text(switch (runtime.status) {
              'active' => 'Обработка применена к сигналу микрофона.',
              'initializing' => 'Ожидаем обработанные кадры микрофона.',
              'unsupported' => 'Capture processor недоступен для этого формата. Настройки не применены.',
              'error' =>
                'Не удалось проверить обработку. Применение не подтверждено.',
              _ => 'Микрофон выключен.',
            }),
          ] else ...[
            if (agc)
              Text(
                'Управляется автоматически. Ручное значение сохранено: ${value.round()}%.',
              )
            else
              const Text(
                'Усиление отправляемого сигнала. 100% — без дополнительного усиления.',
              ),
            Semantics(
              liveRegion: true,
              child: Text(
                runtime.clipping
                    ? 'Перегрузка: уменьшите громкость микрофона.'
                    : 'Перегрузка не обнаружена.',
              ),
            ),
          ],
          TextButton(
            onPressed: disabled
                ? null
                : () => sensitivity
                      ? onChanged(vadThresholdDb: -50)
                      : onChanged(microphoneGainPercent: 100),
            child: Text(
              sensitivity ? 'Сбросить чувствительность' : 'Сбросить громкость',
            ),
          ),
        ],
      );
    },
  );
}
