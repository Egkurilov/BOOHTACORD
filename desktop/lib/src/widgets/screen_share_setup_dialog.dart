import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' show VideoDimensions;
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../services/screen_share_quality.dart';
import '../theme.dart';

class ScreenShareSetupSelection {
  const ScreenShareSetupSelection({
    required this.sourceId,
    required this.quality,
    this.sourceDimensions,
  });

  final String? sourceId;
  final ScreenShareQuality quality;
  final VideoDimensions? sourceDimensions;
}

class ScreenShareSetupDialog extends StatefulWidget {
  const ScreenShareSetupDialog({
    super.key,
    required this.initialQuality,
    required this.allowSourceSelection,
    this.updating = false,
  });

  final ScreenShareQuality initialQuality;
  final bool allowSourceSelection;
  final bool updating;

  static Future<ScreenShareSetupSelection?> show(
    BuildContext context, {
    required ScreenShareQuality initialQuality,
    required bool allowSourceSelection,
    bool updating = false,
  }) => showDialog<ScreenShareSetupSelection>(
    context: context,
    barrierDismissible: false,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    builder: (_) => ScreenShareSetupDialog(
      initialQuality: initialQuality,
      allowSourceSelection: allowSourceSelection,
      updating: updating,
    ),
  );

  @override
  State<ScreenShareSetupDialog> createState() => _ScreenShareSetupDialogState();
}

class _ScreenShareSetupDialogState extends State<ScreenShareSetupDialog> {
  final Map<String, rtc.DesktopCapturerSource> _sources = {};
  final List<StreamSubscription<rtc.DesktopCapturerSource>> _subscriptions = [];
  late ScreenShareQuality _quality;
  rtc.SourceType _sourceType = rtc.SourceType.Screen;
  String? _selectedSourceId;
  Timer? _refreshTimer;
  bool _loading = true;
  String? _loadError;
  int _resolution = 720;
  int _frameRate = 15;

  @override
  void initState() {
    super.initState();
    _quality = widget.initialQuality;
    _resolution = _quality.resolution;
    _frameRate = _quality.frameRate;
    if (widget.allowSourceSelection) {
      _listenForSourceChanges();
      unawaited(_loadSources());
      _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        unawaited(_updateSources());
      });
    }
  }

  void _listenForSourceChanges() {
    final capturer = rtc.desktopCapturer;
    _subscriptions.add(
      capturer.onAdded.stream.listen((source) {
        if (!mounted || source.type != _sourceType) return;
        setState(() => _sources[source.id] = source);
      }),
    );
    _subscriptions.add(
      capturer.onRemoved.stream.listen((source) {
        if (!mounted) return;
        setState(() {
          _sources.remove(source.id);
          if (_selectedSourceId == source.id) _selectedSourceId = null;
        });
      }),
    );
    _subscriptions.add(
      capturer.onThumbnailChanged.stream.listen((source) {
        if (!mounted || source.type != _sourceType) return;
        setState(() => _sources[source.id] = source);
      }),
    );
    _subscriptions.add(
      capturer.onNameChanged.stream.listen((source) {
        if (!mounted || source.type != _sourceType) return;
        setState(() => _sources[source.id] = source);
      }),
    );
  }

  Future<void> _loadSources() async {
    if (!mounted || !widget.allowSourceSelection) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final sources = await rtc.desktopCapturer.getSources(
        types: [_sourceType],
        thumbnailSize: rtc.ThumbnailSize(640, 360),
      );
      if (!mounted) return;
      setState(() {
        _sources
          ..clear()
          ..addEntries(sources.map((source) => MapEntry(source.id, source)));
        if (!_sources.containsKey(_selectedSourceId)) {
          _selectedSourceId = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Не удалось получить список источников.';
      });
    }
  }

  Future<void> _updateSources() async {
    if (!mounted || !widget.allowSourceSelection) return;
    try {
      await rtc.desktopCapturer.updateSources(types: [_sourceType]);
    } catch (_) {
      // Keep the last usable list; the explicit refresh action reports errors.
    }
  }

  void _selectSourceType(rtc.SourceType type) {
    if (type == _sourceType) return;
    setState(() {
      _sourceType = type;
      _selectedSourceId = null;
      _sources.clear();
    });
    unawaited(_loadSources());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  void _close([ScreenShareSetupSelection? selection]) {
    Navigator.of(context).pop(selection);
  }

  ScreenShareSetupSelection _selection() {
    final source = _sources[_selectedSourceId];
    return ScreenShareSetupSelection(
      sourceId: _selectedSourceId,
      quality: _quality,
      sourceDimensions: ScreenShareQuality.sourceDimensionsFromJpeg(
        source?.thumbnail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final compact = media.width < 640;
    final height = math.min(760.0, media.height * .9);
    final selectedSource = _sources[_selectedSourceId];
    final selectedSourceDimensions =
        ScreenShareQuality.sourceDimensionsFromJpeg(selectedSource?.thumbnail);
    final canStart =
        !widget.allowSourceSelection ||
        (selectedSource != null &&
            (defaultTargetPlatform != TargetPlatform.windows ||
                selectedSourceDimensions != null));
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 960, maxHeight: height),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GcColors.sidebar,
            border: Border.all(color: GcColors.border),
            borderRadius: BorderRadius.circular(GcRadii.shell),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 42,
                offset: Offset(0, 22),
              ),
            ],
          ),
          child: SizedBox(
            width: 960,
            height: height,
            child: Column(
              children: [
                _buildHeader(),
                if (widget.allowSourceSelection) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                    child: SegmentedButton<rtc.SourceType>(
                      segments: const [
                        ButtonSegment(
                          value: rtc.SourceType.Screen,
                          icon: Icon(Icons.desktop_windows_outlined),
                          label: Text('Весь экран'),
                        ),
                        ButtonSegment(
                          value: rtc.SourceType.Window,
                          icon: Icon(Icons.web_asset_outlined),
                          label: Text('Окно'),
                        ),
                      ],
                      selected: {_sourceType},
                      onSelectionChanged: (values) =>
                          _selectSourceType(values.first),
                    ),
                  ),
                  Expanded(child: _buildSourceGrid()),
                  _buildQualityPicker(),
                ] else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: compact ? 12 : 20),
                          if (!widget.updating) _buildMobileCaptureNotice(),
                          SizedBox(height: compact ? 8 : 20),
                          _buildQualityPicker(),
                        ],
                      ),
                    ),
                  ),
                ],
                _buildFooter(
                  canStart,
                  compact: compact,
                  sourceDimensions: selectedSourceDimensions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: GcColors.accent.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(GcRadii.md),
          ),
          child: const Icon(
            Icons.screen_share_outlined,
            color: GcColors.accentText,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Демонстрация экрана',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                widget.updating
                    ? 'Изменить качество и FPS без перезапуска'
                    : defaultTargetPlatform == TargetPlatform.iOS
                    ? 'Выберите качество трансляции приложения'
                    : 'Выберите источник и качество трансляции',
                style: const TextStyle(
                  color: GcColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Закрыть',
          onPressed: () => _close(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _buildSourceGrid() {
    if (_loading && _sources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: GcColors.warning,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              _loadError!,
              style: const TextStyle(color: GcColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => unawaited(_loadSources()),
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    final sources = _sources.values
        .where((source) => source.type == _sourceType)
        .toList(growable: false);
    if (sources.isEmpty) {
      final isScreen = _sourceType == rtc.SourceType.Screen;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isScreen ? Icons.desktop_access_disabled : Icons.web_asset_off,
              color: GcColors.muted,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              isScreen ? 'Экраны не найдены' : 'Открытые окна не найдены',
              style: const TextStyle(color: GcColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.58,
      ),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        final selected = source.id == _selectedSourceId;
        return _SourceCard(
          key: ValueKey(source.id),
          source: source,
          selected: selected,
          onTap: () => setState(() => _selectedSourceId = source.id),
        );
      },
    );
  }

  Widget _buildMobileCaptureNotice() => Container(
    margin: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width < 640 ? 16 : 28,
    ),
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 640 ? 16 : 24),
    constraints: const BoxConstraints(maxWidth: 520),
    decoration: BoxDecoration(
      color: GcColors.surface,
      border: Border.all(color: GcColors.border),
      borderRadius: BorderRadius.circular(GcRadii.lg),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.privacy_tip_outlined,
          color: GcColors.accentText,
          size: 28,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            defaultTargetPlatform == TargetPlatform.iOS
                ? 'На iPhone транслируется только содержимое BOOHTACORD. Другие приложения и системный звук не передаются. Остановить трансляцию можно в голосовом канале.'
                : 'После продолжения Android покажет системный запрос на запись экрана. Вы сможете остановить трансляцию в любой момент.',
            style: const TextStyle(color: GcColors.textSecondary, height: 1.45),
          ),
        ),
      ],
    ),
  );

  Widget _buildQualityPicker() {
    final compact = MediaQuery.sizeOf(context).width < 640;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        12,
        compact ? 16 : 24,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 17, color: GcColors.textSecondary),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Качество трансляции',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildQualityOption(
            label: 'Разрешение',
            selectorKey: const ValueKey('resolution-segments'),
            compact: compact,
            selected: _resolution,
            values: ScreenShareQuality.resolutions,
            labelFor: (value) =>
                Text('${value}p', maxLines: 1, softWrap: false),
            onSelectionChanged: (values) => setState(() {
              _resolution = values.first;
              _quality = ScreenShareQuality(
                resolution: _resolution,
                frameRate: _frameRate,
              );
            }),
          ),
          const SizedBox(height: 12),
          _buildQualityOption(
            label: 'Частота кадров',
            selectorKey: const ValueKey('frame-rate-segments'),
            compact: compact,
            selected: _frameRate,
            values: ScreenShareQuality.frameRates,
            labelFor: (value) =>
                Text('$value FPS', maxLines: 1, softWrap: false),
            onSelectionChanged: (values) => setState(() {
              _frameRate = values.first;
              _quality = ScreenShareQuality(
                resolution: _resolution,
                frameRate: _frameRate,
              );
            }),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: compact ? 0 : 104),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.network_check,
                    size: 15,
                    color: GcColors.muted,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Ориентировочно ${_quality.estimatedBandwidth}; более высокое качество увеличивает нагрузку на сеть и устройство.',
                    style: const TextStyle(color: GcColors.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityOption({
    required String label,
    required Key selectorKey,
    required bool compact,
    required int selected,
    required List<int> values,
    required Widget Function(int value) labelFor,
    required ValueChanged<Set<int>> onSelectionChanged,
  }) {
    final selector = SizedBox(
      key: selectorKey,
      width: double.infinity,
      child: SegmentedButton<int>(
        // On phone-width dialogs, the selected icon competes with short labels
        // (for example, "720p" and "15 FPS") for each segment's limited width.
        // The selected background and semantics still indicate the active value.
        showSelectedIcon: !compact,
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            TextStyle(fontSize: compact ? 13 : 14),
          ),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: compact ? 6 : 12, vertical: 12),
          ),
        ),
        segments: [
          for (final value in values)
            ButtonSegment(value: value, label: labelFor(value)),
        ],
        selected: {selected},
        onSelectionChanged: onSelectionChanged,
      ),
    );
    final description = Text(
      label,
      style: const TextStyle(color: GcColors.textSecondary, fontSize: 13),
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [description, const SizedBox(height: 6), selector],
      );
    }
    return Row(
      children: [
        SizedBox(width: 104, child: description),
        Expanded(child: selector),
      ],
    );
  }

  Widget _buildFooter(
    bool canStart, {
    required bool compact,
    required VideoDimensions? sourceDimensions,
  }) {
    final selectedSource = _sources[_selectedSourceId];
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 24,
        14,
        compact ? 12 : 24,
        18,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: GcColors.border)),
      ),
      child: compact
          ? OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 10,
              overflowSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => _close(),
                  child: const Text('Отмена'),
                ),
                FilledButton.icon(
                  key: const ValueKey('start-screen-share'),
                  onPressed: canStart
                      ? () => _close(
                          ScreenShareSetupSelection(
                            sourceId: _selectedSourceId,
                            quality: _quality,
                            sourceDimensions: sourceDimensions,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.screen_share_outlined),
                  label: Text(
                    widget.updating
                        ? 'Применить качество'
                        : 'Начать трансляцию',
                  ),
                ),
              ],
            )
          : Row(
              children: [
                if (widget.allowSourceSelection)
                  Expanded(
                    child: Text(
                      canStart
                          ? 'Выбрано: ${_sources[_selectedSourceId]?.name ?? ''}'
                          : selectedSource != null &&
                                defaultTargetPlatform == TargetPlatform.windows
                          ? 'Получаем размер источника…'
                          : 'Сначала выберите экран или окно',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GcColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                TextButton(
                  onPressed: () => _close(),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const ValueKey('start-screen-share'),
                  onPressed: canStart ? () => _close(_selection()) : null,
                  icon: const Icon(Icons.screen_share_outlined),
                  label: Text(
                    widget.updating
                        ? 'Применить качество'
                        : 'Начать трансляцию',
                  ),
                ),
              ],
            ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    super.key,
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final rtc.DesktopCapturerSource source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Uint8List? thumbnail = source.thumbnail;
    return Material(
      color: GcColors.surface,
      borderRadius: BorderRadius.circular(GcRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? GcColors.focus : GcColors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(GcRadii.md),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnail != null && thumbnail.isNotEmpty)
                      Image.memory(
                        thumbnail,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      )
                    else
                      const ColoredBox(
                        color: GcColors.canvas,
                        child: Center(
                          child: Icon(
                            Icons.desktop_windows_outlined,
                            color: GcColors.muted,
                            size: 34,
                          ),
                        ),
                      ),
                    if (selected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: GcColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Icon(
                      source.type == rtc.SourceType.Screen
                          ? Icons.desktop_windows_outlined
                          : Icons.web_asset_outlined,
                      size: 16,
                      color: selected ? GcColors.accentText : GcColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? GcColors.text
                              : GcColors.textSecondary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
