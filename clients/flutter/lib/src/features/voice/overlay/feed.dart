import 'package:flutter/foundation.dart';

import 'projection.dart';

class VoiceOverlayFeed extends ChangeNotifier {
  VoiceOverlayFeed({required List<Listenable> sources, required this.project})
    : _sources = List.unmodifiable(sources),
      snapshot = project() {
    for (final source in _sources) {
      source.addListener(_refresh);
    }
  }

  final List<Listenable> _sources;
  final VoiceOverlaySnapshot Function() project;
  VoiceOverlaySnapshot snapshot;

  void _refresh() {
    snapshot = project();
    notifyListeners();
  }

  @override
  void dispose() {
    snapshot = const VoiceOverlaySnapshot(visible: false, members: []);
    notifyListeners();
    for (final source in _sources) {
      source.removeListener(_refresh);
    }
    super.dispose();
  }
}
