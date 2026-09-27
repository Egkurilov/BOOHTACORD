import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../theme.dart';

class ScreenReceiverSnapshot {
  const ScreenReceiverSnapshot({
    required this.timestampMs,
    this.bytesReceived,
    this.framesDecoded,
    this.framesDropped,
    this.jitterSeconds,
    this.packetsLost,
    this.frameWidth,
    this.frameHeight,
    this.framesPerSecond,
  });

  final double timestampMs;
  final double? bytesReceived;
  final double? framesDecoded;
  final double? framesDropped;
  final double? jitterSeconds;
  final double? packetsLost;
  final double? frameWidth;
  final double? frameHeight;
  final double? framesPerSecond;
}

class ScreenReceiverMetrics {
  const ScreenReceiverMetrics({
    this.bitrateKbps,
    this.decodedFps,
    this.droppedFrames,
    this.jitterMs,
    this.packetsLost,
  });

  final double? bitrateKbps;
  final double? decodedFps;
  final double? droppedFrames;
  final double? jitterMs;
  final double? packetsLost;
}

ScreenReceiverMetrics compareScreenReceiverStats(
  ScreenReceiverSnapshot? previous,
  ScreenReceiverSnapshot current,
) {
  final elapsedMs = previous == null
      ? null
      : current.timestampMs - previous.timestampMs;
  return ScreenReceiverMetrics(
    bitrateKbps: _rate(
      previous?.bytesReceived,
      current.bytesReceived,
      elapsedMs,
      8,
    ),
    decodedFps: _rate(
      previous?.framesDecoded,
      current.framesDecoded,
      elapsedMs,
      1000,
    ),
    droppedFrames: _delta(
      previous?.framesDropped,
      current.framesDropped,
      elapsedMs,
    ),
    jitterMs: _finiteNonNegative(current.jitterSeconds)
        ? current.jitterSeconds! * 1000
        : null,
    packetsLost: _finiteNonNegative(current.packetsLost)
        ? current.packetsLost
        : null,
  );
}

double? _rate(
  double? previous,
  double? current,
  double? elapsedMs,
  double multiplier,
) {
  if (!_finiteNonNegative(previous) ||
      !_finiteNonNegative(current) ||
      !_finiteNonNegative(elapsedMs) ||
      elapsedMs == 0 ||
      current! < previous!) {
    return null;
  }
  return _round((current - previous) * multiplier / elapsedMs!, 1);
}

double? _delta(double? previous, double? current, double? elapsedMs) {
  if (!_finiteNonNegative(previous) ||
      !_finiteNonNegative(current) ||
      !_finiteNonNegative(elapsedMs) ||
      elapsedMs == 0 ||
      current! < previous!) {
    return null;
  }
  return current - previous;
}

bool _finiteNonNegative(double? value) =>
    value != null && value.isFinite && value >= 0;

double _round(double value, int places) {
  final multiplier = switch (places) {
    0 => 1.0,
    1 => 10.0,
    _ => 100.0,
  };
  return (value * multiplier).round() / multiplier;
}

class ScreenReceiverDiagnostics extends StatefulWidget {
  const ScreenReceiverDiagnostics({
    super.key,
    required this.track,
    required this.isLocal,
    required this.hasAudio,
  });

  final RemoteVideoTrack? track;
  final bool isLocal;
  final bool hasAudio;

  @override
  State<ScreenReceiverDiagnostics> createState() =>
      _ScreenReceiverDiagnosticsState();
}

class _ScreenReceiverDiagnosticsState extends State<ScreenReceiverDiagnostics> {
  Timer? _timer;
  ScreenReceiverSnapshot? _previous;
  ScreenReceiverSnapshot? _current;
  ScreenReceiverMetrics? _metrics;
  DateTime? _sampledAt;
  bool _sampling = false;
  String _sampleStatus = 'Ожидание статистики приёмника';

  @override
  void initState() {
    super.initState();
    _restartSampling();
  }

  @override
  void didUpdateWidget(covariant ScreenReceiverDiagnostics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track) _restartSampling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartSampling() {
    _timer?.cancel();
    _previous = null;
    _current = null;
    _metrics = null;
    _sampledAt = null;
    final track = widget.track;
    _sampleStatus = widget.isLocal
        ? 'Метрики приёмника не применимы к предпросмотру'
        : track == null
        ? 'Видеоприёмник недоступен'
        : 'Ожидание статистики приёмника';
    if (track == null) return;
    unawaited(_sample(track));
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_sample(track)),
    );
  }

  Future<void> _sample(RemoteVideoTrack track) async {
    if (_sampling) return;
    _sampling = true;
    try {
      final stats = await track.getReceiverStats();
      if (!mounted || !identical(track, widget.track)) return;
      if (stats == null) {
        setState(() => _sampleStatus = 'Приёмник не вернул статистику');
        return;
      }
      final next = ScreenReceiverSnapshot(
        timestampMs: stats.timestamp.toDouble(),
        bytesReceived: stats.bytesReceived?.toDouble(),
        framesDecoded: stats.framesDecoded?.toDouble(),
        framesDropped: stats.framesDropped?.toDouble(),
        jitterSeconds: stats.jitter?.toDouble(),
        packetsLost: stats.packetsLost?.toDouble(),
        frameWidth: stats.frameWidth?.toDouble(),
        frameHeight: stats.frameHeight?.toDouble(),
        framesPerSecond: stats.framesPerSecond?.toDouble(),
      );
      final metrics = compareScreenReceiverStats(_previous, next);
      _previous = next;
      setState(() {
        _current = next;
        _metrics = metrics;
        _sampledAt = DateTime.now();
        _sampleStatus = 'Измерено в ${_formatTime(_sampledAt!)}';
      });
    } catch (_) {
      if (mounted && identical(track, widget.track)) {
        setState(() => _sampleStatus = 'Не удалось прочитать статистику');
      }
    } finally {
      _sampling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sampledAt = _sampledAt;
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 12),
      title: const Text('Статистика'),
      subtitle: Text(_sampleStatus),
      children: [
        SizedBox(
          height: 240,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 10),
            children: [
              const _DiagnosticRow(
                label: 'Профиль источника',
                value: 'Не передан источником',
              ),
              _DiagnosticRow(
                label: 'Сейчас у зрителя',
                value: _formatResolution(_current),
              ),
              _DiagnosticRow(
                label: 'Декодировано',
                value: _formatMetric(
                  _metrics?.decodedFps ?? _current?.framesPerSecond,
                  'FPS',
                ),
              ),
              _DiagnosticRow(
                label: 'Получено',
                value: _formatMetric(_metrics?.bitrateKbps, 'кбит/с'),
              ),
              _DiagnosticRow(
                label: 'Потеряно пакетов',
                value: _formatMetric(_metrics?.packetsLost),
              ),
              _DiagnosticRow(
                label: 'Пропущено кадров за интервал',
                value: _formatMetric(_metrics?.droppedFrames),
              ),
              _DiagnosticRow(
                label: 'Jitter',
                value: _formatMetric(_metrics?.jitterMs, 'мс'),
              ),
              const _DiagnosticRow(
                label: 'RTT',
                value: 'Нет данных от приёмника',
              ),
              _DiagnosticRow(
                label: 'Аудиодорожка',
                value: widget.isLocal
                    ? 'Предпросмотр без звука'
                    : widget.hasAudio
                    ? 'Аудиодорожка есть'
                    : 'Аудиодорожки нет',
              ),
              _DiagnosticRow(
                label: 'Последнее измерение',
                value: sampledAt == null
                    ? 'Нет свежих данных'
                    : _formatTime(sampledAt),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: GcColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

String _formatResolution(ScreenReceiverSnapshot? sample) {
  if (sample == null ||
      !_finiteNonNegative(sample.frameWidth) ||
      !_finiteNonNegative(sample.frameHeight)) {
    return 'Нет данных';
  }
  final fps = _finiteNonNegative(sample.framesPerSecond)
      ? ' · ${sample.framesPerSecond!.round()} FPS'
      : '';
  return '${sample.frameWidth!.round()} × ${sample.frameHeight!.round()}$fps';
}

String _formatMetric(double? value, [String unit = '']) {
  if (!_finiteNonNegative(value)) return 'Нет данных';
  final rendered = value! % 1 == 0
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
  return unit.isEmpty ? rendered : '$rendered $unit';
}

String _formatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
