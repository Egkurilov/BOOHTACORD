import 'package:flutter/foundation.dart';

import 'model.dart';

class GuildProfileController extends ChangeNotifier {
  GuildProfileController(this.read);
  final Future<GuildProfile> Function() read;
  String name = 'BOOHTACORD';
  int revision = 0, _generation = 0;
  bool _disposed = false;
  Future<void> refresh([int minimumRevision = 0]) async {
    final generation = _generation;
    try {
      final profile = await read().timeout(const Duration(seconds: 20));
      if (!_disposed &&
          generation == _generation &&
          profile.revision >= revision &&
          profile.revision >= minimumRevision) {
        name = profile.name;
        revision = profile.revision;
        notifyListeners();
      }
    } catch (_) {
      /* Keep the last public metadata during outages. */
    }
  }

  void reset() {
    _generation++;
    name = 'BOOHTACORD';
    revision = 0;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
