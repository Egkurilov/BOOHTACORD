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
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final freshSamples = samples
        .where((sample) {
          final age = now.difference(sample.sampledAtUtc);
          return age >= const Duration(seconds: -5) &&
              age <= const Duration(seconds: 60);
        })
        .toList(growable: false);
    final header = Padding(
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
                  style: TextStyle(color: GcColors.textSecondary, fontSize: 12),
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
    );
    final bodyChildren = <Widget>[
      const Text(
        'Сравните размер кадра и FPS отправки, приёма и показа: так проще найти участок потери разрешения или кадров. Данные сообщают сами клиенты; они не подтверждают содержимое кадра или аппаратный профиль.',
        style: TextStyle(
          color: GcColors.textSecondary,
          fontSize: 13,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 12),
      _freshnessSummary(freshSamples.length),
      const SizedBox(height: 12),
      if (loading && samples.isEmpty && error == null)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (error != null)
        Semantics(
          liveRegion: true,
          child: Text(error!, style: const TextStyle(color: GcColors.danger)),
        )
      else if (freshSamples.isEmpty &&
          (samples.isNotEmpty || lastSeenAt != null))
        Semantics(
          liveRegion: true,
          child: Text(
            'Свежих показателей нет. Последнее измерение: ${lastSeenAt == null ? 'время неизвестно' : formatDate(lastSeenAt!)}.',
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
        for (final sample in freshSamples) _sampleCard(context, sample),
      ],
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    if (largeText) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          header,
          Padding(
            padding: listPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: bodyChildren,
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        header,
        Expanded(
          child: ListView(padding: listPadding, children: bodyChildren),
        ),
      ],
    );
  }

  Widget _freshnessSummary(int freshCount) {
    final lastSeen = lastSeenAt;
    final age = lastSeen == null
        ? null
        : DateTime.now().toUtc().difference(lastSeen).inSeconds;
    final state = error != null
        ? 'Ошибка обновления'
        : loading && samples.isEmpty
        ? 'Загружаем показатели'
        : freshCount > 0
        ? 'Есть свежие данные'
        : samples.isNotEmpty || lastSeen != null || (age != null && age > 60)
        ? 'Данные устарели'
        : 'Нет данных';
    final color = error != null
        ? GcColors.danger
        : state == 'Есть свежие данные'
        ? GcColors.success
        : GcColors.warning;
    return Semantics(
      liveRegion: true,
      child: Text(
        'Состояние: $state · свежих образцов: $freshCount · последнее успешное обновление: ${lastSuccessfulAt == null ? 'нет' : formatDate(lastSuccessfulAt!)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
        Text(
          'Состояние: ${_stateLabel(sample.state)}',
          style: TextStyle(
            color: sample.state == 'stalled'
                ? GcColors.danger
                : GcColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stage(
              'Отправка',
              sample.direction == 'sender'
                  ? _value(sample.encodedFps, 'FPS')
                  : 'Нет данных',
            ),
            _stage(
              'Приём',
              sample.direction == 'receiver' &&
                      sample.frameWidth != null &&
                      sample.frameHeight != null
                  ? '${sample.frameWidth} × ${sample.frameHeight}'
                  : 'Нет данных',
            ),
            _stage(
              'Декодирование',
              sample.direction == 'receiver'
                  ? _value(sample.decodedFps, 'FPS')
                  : 'Нет данных',
            ),
            _stage(
              'Показ',
              sample.direction == 'receiver'
                  ? _value(sample.presentedFps, 'FPS')
                  : 'Нет данных',
            ),
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

  Widget _stage(String title, String value) => Container(
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
        Text(value),
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
