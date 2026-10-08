import 'package:flutter/foundation.dart';

import 'projection.dart';

class VoiceOverlayFeed extends ChangeNotifier {
  VoiceOverlayFeed({required List<Listenable> sources, required this.project})
    : _sources = List.unmodifiable(sources),
      snapshot = project(false, false);

  final List<Listenable> _sources;
  final VoiceOverlaySnapshot Function(bool enabled, bool onlySpeakers) project;
  VoiceOverlaySnapshot snapshot;
  bool enabled = false;
  bool onlySpeakers = false;
  int maxParticipants = 8;
  void setMaxParticipants(int value) {
    maxParticipants = value.clamp(1, 12);
    _refresh();
  }

  void setEnabled(bool value) {
    if (enabled == value) return;
    enabled = value;
    for (final source in _sources) {
      if (value) {
        source.addListener(_refresh);
      } else {
        source.removeListener(_refresh);
      }
    }
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
    if (enabled) {
      for (final source in _sources) {
        source.removeListener(_refresh);
      }
    }
    enabled = false;
    onlySpeakers = false;
    snapshot = const VoiceOverlaySnapshot(visible: false, members: []);
    notifyListeners();
    super.dispose();
  }
}
