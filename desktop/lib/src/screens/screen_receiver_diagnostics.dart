import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../services/screen_share_metrics.dart';
import '../services/screen_receiver_report.dart';
import '../theme.dart';
import 'screen_packet_loss.dart';

class ScreenReceiverSnapshot {
  const ScreenReceiverSnapshot({
    required this.timestampMs,
    this.bytesReceived,
    this.framesDecoded,
    this.framesDropped,
    this.jitterSeconds,
    this.packetsLost,
    this.packetsReceived,
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
  final double? packetsReceived;
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
    this.packetLossPercent,
  });

  final double? bitrateKbps;
  final double? decodedFps;
  final double? droppedFrames;
  final double? jitterMs;
  final double? packetsLost;
  final double? packetLossPercent;
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
    this.selectedStreamId,
    this.reportEnabled = true,
    this.onReport,
    this.sourceTrackName,
  });

  final RemoteVideoTrack? track;
  final bool isLocal;
  final bool hasAudio;
  final String? selectedStreamId;
  final bool reportEnabled;
  final Future<void> Function(Map<String, Object> report)? onReport;
  final String? sourceTrackName;

  @override
  State<ScreenReceiverDiagnostics> createState() =>
      _ScreenReceiverDiagnosticsState();
}

class _ScreenReceiverDiagnosticsState extends State<ScreenReceiverDiagnostics>
    with WidgetsBindingObserver {
  final OverlayPortalController _popoverController = OverlayPortalController();
  final LayerLink _summaryLink = LayerLink();
  final GlobalKey _summaryKey = GlobalKey();
  final FocusNode _focusNode = FocusNode(debugLabel: 'Статистика трансляции');
  Timer? _timer;
  Timer? _reportTimer;
  int _samplingGeneration = 0;
  ScreenReceiverSnapshot? _previous;
  ScreenReceiverSnapshot? _current;
  ScreenReceiverMetrics? _metrics;
  final ScreenPacketLossWindow _lossWindow = ScreenPacketLossWindow();
  DateTime? _sampledAt;
  bool _sampling = false;
  bool _reporting = false;
  bool _appVisible = true;
  bool _popoverOpen = false;
  String _sampleStatus = 'Ожидание статистики приёмника';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restartSampling();
  }

  @override
  void didUpdateWidget(covariant ScreenReceiverDiagnostics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track != widget.track ||
        oldWidget.isLocal != widget.isLocal ||
        oldWidget.reportEnabled != widget.reportEnabled ||
        oldWidget.selectedStreamId != widget.selectedStreamId) {
      _restartSampling();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _reportTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
  }

  void _togglePopover() {
    setState(() => _popoverOpen = !_popoverOpen);
    if (_popoverOpen) {
      _popoverController.show();
      _focusNode.requestFocus();
    } else {
      _popoverController.hide();
    }
  }

  void _closePopover() {
    if (!_popoverOpen) return;
    setState(() => _popoverOpen = false);
    _popoverController.hide();
  }

  void _restartSampling() {
    final generation = ++_samplingGeneration;
    _timer?.cancel();
    _sampling = false;
    _previous = null;
    _lossWindow.clear();
    _current = null;
    _metrics = null;
    _sampledAt = null;
    _reportTimer?.cancel();
    _reporting = false;
    if (!widget.isLocal &&
        widget.reportEnabled &&
        widget.onReport != null) {
      _reportTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_submitReport()),
      );
    }
    final track = widget.track;
    _sampleStatus = widget.isLocal
        ? 'Метрики приёмника не применимы к предпросмотру'
        : track == null
        ? 'Видеоприёмник недоступен'
        : 'Ожидание статистики приёмника';
    if (track == null) return;
    unawaited(_sample(track, generation));
    _timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_sample(track, generation)),
    );
  }

  Future<void> _submitReport() async {
    final reportCallback = widget.onReport;
    if (_reporting ||
        !mounted ||
        !_appVisible ||
        widget.isLocal ||
        !widget.reportEnabled ||
        reportCallback == null) {
      return;
    }
    final platform = nativeScreenMetricsPlatform(defaultTargetPlatform);
    if (platform == null) return;
    final report = buildScreenReceiverReport(
      platform: platform,
      selected: true,
      hasTrack: widget.track != null,
      current: _current,
      metrics: _metrics,
    );
    if (report == null) return;
    _reporting = true;
    try {
      await reportCallback(report);
    } catch (_) {
      // Best-effort diagnostics must not interrupt screen playback.
    } finally {
      _reporting = false;
    }
  }

  Future<void> _sample(RemoteVideoTrack track, int generation) async {
    if (_sampling || generation != _samplingGeneration) return;
    _sampling = true;
    try {
      final stats = await track.getReceiverStats();
      if (!mounted ||
          generation != _samplingGeneration ||
          !identical(track, widget.track)) {
        return;
      }
      if (stats == null) {
        _previous = null;
        _lossWindow.clear();
        setState(() {
          _metrics = null;
          _sampledAt = null;
          _sampleStatus = 'Приёмник не вернул статистику';
        });
        return;
      }
      final next = ScreenReceiverSnapshot(
        timestampMs: stats.timestamp.toDouble(),
        bytesReceived: stats.bytesReceived?.toDouble(),
        framesDecoded: stats.framesDecoded?.toDouble(),
        framesDropped: stats.framesDropped?.toDouble(),
        jitterSeconds: stats.jitter?.toDouble(),
        packetsLost: stats.packetsLost?.toDouble(),
        packetsReceived: stats.packetsReceived?.toDouble(),
        frameWidth: stats.frameWidth?.toDouble(),
        frameHeight: stats.frameHeight?.toDouble(),
        framesPerSecond: stats.framesPerSecond?.toDouble(),
      );
      final measured = compareScreenReceiverStats(_previous, next);
      final metrics = ScreenReceiverMetrics(
        bitrateKbps: measured.bitrateKbps,
        decodedFps: measured.decodedFps,
        droppedFrames: measured.droppedFrames,
        jitterMs: measured.jitterMs,
        packetsLost: measured.packetsLost,
        packetLossPercent: _lossWindow.add(
          timestampMs: next.timestampMs,
          packetsReceived: next.packetsReceived,
          packetsLost: next.packetsLost,
        ),
      );
      _previous = next;
      setState(() {
        _current = next;
        _metrics = metrics;
        _sampledAt = DateTime.now();
        _sampleStatus = 'Измерено в ${_formatTime(_sampledAt!)}';
      });
    } catch (_) {
      if (mounted &&
          generation == _samplingGeneration &&
          identical(track, widget.track)) {
        _previous = null;
        _lossWindow.clear();
        setState(() {
          _metrics = null;
          _sampledAt = null;
          _sampleStatus = 'Не удалось прочитать статистику';
        });
      }
    } finally {
      if (generation == _samplingGeneration) _sampling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sampledAt = _sampledAt;
    final compact = MediaQuery.sizeOf(context).width <= 1100;
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (_popoverOpen &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closePopover();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: OverlayPortal(
        controller: _popoverController,
        overlayChildBuilder: (context) {
          final media = MediaQuery.sizeOf(context);
          final panelWidth = math.min(288.0, media.width - 32);
          final summaryBox =
              _summaryKey.currentContext?.findRenderObject() as RenderBox?;
          final summaryTop = summaryBox?.localToGlobal(Offset.zero).dy ?? 0;
          final summaryBottom = summaryTop + (summaryBox?.size.height ?? 36);
          final spaceBelow = media.height - summaryBottom - 32;
          final spaceAbove = summaryTop - 32;
          final openAbove = spaceBelow < 360 && spaceAbove > spaceBelow;
          final availableHeight = openAbove ? spaceAbove : spaceBelow;
          return SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closePopover,
                    child: const SizedBox.expand(),
                  ),
                ),
                CompositedTransformFollower(
                  link: _summaryLink,
                  showWhenUnlinked: false,
                  targetAnchor: openAbove
                      ? (compact ? Alignment.topLeft : Alignment.topRight)
                      : (compact
                            ? Alignment.bottomLeft
                            : Alignment.bottomRight),
                  followerAnchor: openAbove
                      ? (compact ? Alignment.bottomLeft : Alignment.bottomRight)
                      : (compact ? Alignment.topLeft : Alignment.topRight),
                  offset: Offset(0, openAbove ? -8 : 8),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Container(
                      key: const ValueKey(
                        'screen-receiver-diagnostics-popover',
                      ),
                      width: panelWidth,
                      constraints: BoxConstraints(
                        maxHeight: math.max(
                          160.0,
                          math.min(media.height - 32, availableHeight),
                        ),
                      ),
                      decoration: BoxDecoration(
                        color: GcColors.raised,
                        border: Border.all(color: GcColors.border),
                        borderRadius: BorderRadius.circular(GcRadii.md),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _DiagnosticRow(
                              label: 'Профиль при запуске',
                              value: _screenShareTargetProfile(
                                widget.sourceTrackName,
                              ),
                            ),
                            _DiagnosticRow(
                              label: 'Сейчас у зрителя',
                              value: _formatResolution(_current),
                            ),
                            _DiagnosticRow(
                              label: 'Декодировано',
                              value: _formatMetric(
                                _metrics?.decodedFps ??
                                    _current?.framesPerSecond,
                                'FPS',
                              ),
                            ),
                            _DiagnosticRow(
                              label: 'Получено',
                              value: _formatMetric(
                                _metrics?.bitrateKbps,
                                'кбит/с',
                              ),
                            ),
                            _DiagnosticRow(
                              label: 'Потери пакетов за 10 с',
                              value: formatScreenPacketLossPercent(
                                _metrics?.packetLossPercent,
                              ),
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
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: Align(
          alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
          child: CompositedTransformTarget(
            key: _summaryKey,
            link: _summaryLink,
            child: Tooltip(
              message: _sampleStatus,
              child: Semantics(
                button: true,
                expanded: _popoverOpen,
                label: 'Статистика',
                hint: _sampleStatus,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _togglePopover,
                    borderRadius: BorderRadius.circular(GcRadii.sm),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: GcColors.border),
                        borderRadius: BorderRadius.circular(GcRadii.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: GcColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Статистика',
                            style: TextStyle(
                              color: GcColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _screenShareTargetProfile(String? trackName) {
  final match = RegExp(r'^screenshare-(720|1080|1440)p-(15|30|60)fps$')
      .firstMatch(trackName ?? '');
  return match == null
      ? 'Нет данных от источника'
      : '${match.group(1)}p · ${match.group(2)} FPS';
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: GcColors.muted,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: GcColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ),
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
