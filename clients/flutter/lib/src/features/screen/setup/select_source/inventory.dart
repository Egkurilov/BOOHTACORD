import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

class SourceInventory extends ChangeNotifier {
  SourceInventory({required this.enabled, this.capturer});
  final rtc.DesktopCapturer? capturer;
  final bool enabled;
  final sources = <String, rtc.DesktopCapturerSource>{};
  final subscriptions = <StreamSubscription<rtc.DesktopCapturerSource>>[];
  rtc.SourceType type = rtc.SourceType.Screen;
  String? selectedId;
  String? error;
  bool loading = true;
  bool disposed = false;
  int generation = 0;
  Timer? refreshTimer;
  rtc.DesktopCapturerSource? get selected => sources[selectedId];
  void start() {
    if (!enabled) {
      loading = false;
      return;
    }
    final capturer = this.capturer ?? rtc.desktopCapturer;
    for (final stream in [
      capturer.onAdded.stream,
      capturer.onThumbnailChanged.stream,
      capturer.onNameChanged.stream,
    ]) {
      subscriptions.add(
        stream.listen((source) {
          if (disposed || source.type != type) return;
          sources[source.id] = source;
          notifyListeners();
        }),
      );
    }
    subscriptions.add(
      capturer.onRemoved.stream.listen((source) {
        if (disposed) return;
        sources.remove(source.id);
        if (selectedId == source.id) selectedId = null;
        notifyListeners();
      }),
    );
    unawaited(load());
    refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(update()),
    );
  }

  Future<void> load() async {
    if (disposed || !enabled) return;
    final expected = ++generation;
    final requested = type;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await (capturer ?? rtc.desktopCapturer).getSources(
        types: [requested],
        thumbnailSize: rtc.ThumbnailSize(640, 360),
      );
      if (disposed || expected != generation) return;
      sources
        ..clear()
        ..addEntries(result.map((source) => MapEntry(source.id, source)));
      if (!sources.containsKey(selectedId)) selectedId = null;
      loading = false;
      notifyListeners();
    } catch (_) {
      if (disposed || expected != generation) return;
      loading = false;
      error = 'Не удалось получить список источников.';
      notifyListeners();
    }
  }

  Future<void> update() async {
    if (disposed || !enabled) return;
    try {
      await (capturer ?? rtc.desktopCapturer).updateSources(types: [type]);
    } catch (_) {}
  }

  void selectType(rtc.SourceType value) {
    if (type == value) return;
    type = value;
    selectedId = null;
    sources.clear();
    unawaited(load());
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  @override
  void dispose() {
    disposed = true;
    generation++;
    refreshTimer?.cancel();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
