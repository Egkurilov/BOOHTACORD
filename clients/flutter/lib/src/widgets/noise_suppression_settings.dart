import 'package:flutter/material.dart';

import '../services/audio_preferences.dart';
import '../services/native_noise_suppression.dart';

class NoiseSuppressionSettings extends StatelessWidget {
  const NoiseSuppressionSettings({
    super.key,
    required this.processing,
    required this.runtime,
    required this.onChanged,
  });
  final AudioProcessingPreferences processing;
  final NativeNoiseSuppressionState runtime;
  final Future<void> Function(AudioProcessingPreferences) onChanged;
  static String label(String mode) => switch (mode) {
    'off' => 'Выключено',
    'browser' => 'Стандартное — WebRTC',
    'rnnoise' => 'RNNoise',
    _ => 'Неизвестно',
  };
  static String reason(String? reason) => switch (reason) {
    'platform-aec-ns-coupled' => 'На этой платформе шумоподавление связано с эхоподавлением. Используется стандартная обработка.',
    'hardware-noise-suppression-active' => 'Аппаратный шумодав уже активен.',
    'unsupported-audio-format' =>
      'Формат микрофона не поддерживается фильтром.',
    'invalid-audio-samples' => 'Аудиопроцессор получил некорректные данные.',
    'browser-recovery-failed' || 'rollback-failed' =>
      'Не удалось восстановить микрофон. Отправка звука выключена.',
    'unsupported' => 'Нативный фильтр недоступен.',
    'awaiting-audio' => 'Ожидаем аудио от микрофона.',
    null || '' => '',
    _ => 'Ошибка аудиофильтра.',
  };
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DropdownButtonFormField<NoiseSuppressionMode>(
        key: ValueKey(processing.noiseSuppressionMode),
        initialValue: processing.noiseSuppressionMode,
        decoration: const InputDecoration(labelText: 'Шумоподавление'),
        items: [
          for (final mode in NoiseSuppressionMode.values)
            DropdownMenuItem(
              value: mode,
              enabled:
                  mode != NoiseSuppressionMode.rnnoise ||
                  runtime.status != 'unsupported',
              child: Text(
                mode == NoiseSuppressionMode.rnnoise
                    ? 'RNNoise — экспериментальное'
                    : label(mode.name),
              ),
            ),
        ],
        onChanged: (mode) {
          if (mode != null) {
            onChanged(processing.copyWith(noiseSuppressionMode: mode));
          }
        },
      ),
      const SizedBox(height: 8),
      Text(
        'Выбрано: ${label(processing.noiseSuppressionMode.name)}. Работает: ${label(runtime.effectiveMode)}.',
      ),
      if (runtime.status == 'initializing')
        const Text('Фильтр ожидает первые обработанные кадры.'),
      if (reason(runtime.failureReason).isNotEmpty)
        Text(reason(runtime.failureReason)),
      ExpansionTile(
        title: const Text('Диагностика обработки'),
        children: [
          Text(
            'Статус: ${runtime.status}; обработано кадров: ${runtime.processedFrames}; fallback: ${runtime.fallbackFrames}.',
          ),
          if (runtime.sampleRate != null)
            Text(
              'PCM: ${runtime.sampleRate} Гц; каналы: ${runtime.channels ?? 0}.',
            ),
          const Text(
            'Модель RNNoise: rnnoise-stock-v0.1. Время инициализации нативного DSP: недоступно.',
          ),
          const Text(
            'Capture AEC/AGC остаются независимыми. Нативный SDK не подтверждает акустическое качество.',
          ),
        ],
      ),
    ],
  );
}
