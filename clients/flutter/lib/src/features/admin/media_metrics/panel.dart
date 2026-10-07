import 'package:flutter/material.dart';

import '../../../models.dart';
import '../../../theme.dart';

/// Presentation surface for the media diagnostics tab.
///
/// Loading and refresh state stays in the admin screen, while this widget
/// owns the responsive presentation and metric formatting.
class AdminMediaMetricsPanel extends StatelessWidget {
  const AdminMediaMetricsPanel({
    super.key,
    required this.headerPadding,
    required this.listPadding,
    required this.loading,
    required this.samples,
    required this.error,
    required this.lastSuccessfulAt,
    required this.lastSeenAt,
    required this.onRefresh,
    required this.formatDate,
  });

  final EdgeInsets headerPadding;
  final EdgeInsets listPadding;
  final bool loading;
  final List<AdminScreenSample> samples;
  final String? error;
  final DateTime? lastSuccessfulAt;
  final DateTime? lastSeenAt;
  final VoidCallback onRefresh;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: headerPadding,
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Показатели трансляций',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Последние 60 секунд · без имён и идентификаторов участников',
                    style: TextStyle(
                      color: GcColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: listPadding,
          children: [
            const Text(
              'Сравните размер кадра и FPS отправки, приёма и показа: так проще найти участок потери разрешения или кадров. Данные сообщают сами клиенты; они не подтверждают содержимое кадра или аппаратный профиль.',
              style: TextStyle(
                color: GcColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            _freshnessSummary,
            const SizedBox(height: 12),
            if (loading && samples.isEmpty && error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: const TextStyle(color: GcColors.danger),
                ),
              )
            else if (samples.isEmpty)
              Semantics(
                liveRegion: true,
                child: Text(
                  'Свежих показателей пока нет. Откройте демонстрацию у зрителя.',
                ),
              )
            else ...[
              if (loading) const LinearProgressIndicator(minHeight: 2),
              for (final sample in samples) _sampleCard(context, sample),
            ],
          ],
        ),
      ),
    ],
  );

  Widget get _freshnessSummary {
    final lastSeen = lastSeenAt;
    final age = lastSeen == null
        ? null
        : DateTime.now().toUtc().difference(lastSeen).inSeconds;
    final state = error != null
        ? 'Ошибка обновления'
        : samples.isEmpty
        ? 'Пусто'
        : age != null && age > 15
        ? 'Устарело'
        : 'Свежие данные';
    return Semantics(
      liveRegion: true,
      child: Text(
        'Состояние: $state · свежих образцов: ${samples.length} · последнее успешное обновление: ${lastSuccessfulAt == null ? 'нет' : formatDate(lastSuccessfulAt!)}',
        style: TextStyle(
          color: state == 'Свежие данные' ? GcColors.success : GcColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sampleCard(
    BuildContext context,
    AdminScreenSample sample,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_platformLabel(sample.platform)} · ${sample.direction == 'sender' ? 'отправка' : 'приём'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              TimeOfDay.fromDateTime(sample.sampledAtUtc.toLocal())
                  .format(context),
              style: const TextStyle(
                color: GcColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stage('Отправка', sample.encodedFps, sample.direction == 'sender'),
            _stage('Приём', sample.decodedFps, sample.direction == 'receiver'),
            _stage(
              'Декодирование',
              sample.decodedFps,
              sample.direction == 'receiver',
            ),
            _stage('Показ', sample.presentedFps, sample.presentedFps != null),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _metric('Состояние', _stateLabel(sample.state)),
            _metric(
              'Размер кадра',
              sample.frameWidth == null
                  ? 'Нет данных'
                  : '${sample.frameWidth} × ${sample.frameHeight}',
            ),
            _metric('Отправлено', _value(sample.encodedFps, 'FPS')),
            _metric('Декодировано', _value(sample.decodedFps, 'FPS')),
            _metric('Показано', _value(sample.presentedFps, 'FPS')),
            _metric('Битрейт', _value(sample.bitrateKbps, 'кбит/с')),
            _metric('Потеряно пакетов', _integer(sample.packetsLost)),
            _metric('Пропущено кадров', _integer(sample.droppedFrames)),
            _metric('Jitter', _value(sample.jitterMs, 'мс')),
            _metric('RTT', _value(sample.rttMs, 'мс')),
          ],
        ),
        const SizedBox(height: 4),
        Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text('Дополнительные измерения'),
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _metric('Состояние', _stateLabel(sample.state)),
                  _metric(
                    'Размер кадра',
                    sample.frameWidth == null
                        ? 'Нет данных'
                        : '${sample.frameWidth} × ${sample.frameHeight}',
                  ),
                  _metric('Отправлено', _value(sample.encodedFps, 'FPS')),
                  _metric('Декодировано', _value(sample.decodedFps, 'FPS')),
                  _metric('Показано', _value(sample.presentedFps, 'FPS')),
                  _metric('Битрейт', _value(sample.bitrateKbps, 'кбит/с')),
                  _metric('Потеряно пакетов', _integer(sample.packetsLost)),
                  _metric('Пропущено кадров', _integer(sample.droppedFrames)),
                  _metric('Jitter', _value(sample.jitterMs, 'мс')),
                  _metric('RTT', _value(sample.rttMs, 'мс')),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _stage(String title, double? fps, bool applicable) => Container(
    constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: GcColors.raised,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(applicable ? _value(fps, 'FPS') : 'Нет данных'),
      ],
    ),
  );

  Widget _metric(String label, String value) =>
      SizedBox(width: 220, child: Text('$label · $value'));

  String _platformLabel(String platform) => switch (platform) {
    'ios_web' => 'iPhone/iPad · браузер',
    'android_web' => 'Android · браузер',
    'desktop_web' => 'ПК · браузер',
    'android_native' => 'Android · приложение',
    'desktop_native' => 'ПК · приложение',
    'ios_native' => 'iPhone/iPad · приложение',
    'windows_native' => 'Windows · приложение',
    'macos_native' => 'macOS · приложение',
    _ => 'Неизвестная платформа',
  };

  String _stateLabel(String state) => switch (state) {
    'waiting_subscription' => 'Ожидает видеодорожку',
    'waiting_first_frame' => 'Ожидает первый кадр',
    'playing' => 'Воспроизводит',
    'stalled' => 'Кадры остановились',
    _ => 'Неизвестное состояние',
  };

  String _value(double? value, String unit) {
    if (value == null) return 'Нет данных';
    final formatted = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$formatted $unit';
  }

  String _integer(int? value) => value?.toString() ?? 'Нет данных';
}
