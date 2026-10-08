import 'package:flutter/foundation.dart';

import 'projection.dart';

class VoiceOverlayFeed extends ChangeNotifier {
  VoiceOverlayFeed({required List<Listenable> sources, required this.project})
    : _sources = List.unmodifiable(sources),
      snapshot = project(false, false) {
    for (final source in _sources) {
      source.addListener(_refresh);
    }
  }

  final List<Listenable> _sources;
  final VoiceOverlaySnapshot Function(bool enabled, bool onlySpeakers) project;
  VoiceOverlaySnapshot snapshot;
  bool enabled = false;
  bool onlySpeakers = false;

  void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    _refresh();
  }

  void setOnlySpeakers(bool value) {
    if (onlySpeakers == value) return;
    onlySpeakers = value;
    _refresh();
  }

  void _refresh() {
    snapshot = project(enabled, onlySpeakers);
    notifyListeners();
  }

  @override
  void dispose() {
    enabled = false;
    onlySpeakers = false;
    snapshot = const VoiceOverlaySnapshot(visible: false, members: []);
    notifyListeners();
    for (final source in _sources) {
      source.removeListener(_refresh);
    }
    super.dispose();
  }
}
