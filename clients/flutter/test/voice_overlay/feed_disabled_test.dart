import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/feed.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';

class CountedSource extends ChangeNotifier {
  int registrations = 0;
  @override
  void addListener(VoidCallback listener) {
    registrations++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    registrations--;
    super.removeListener(listener);
  }
}

void main() {
  test('disabled overlay releases source listeners and reenables without duplicates', () {
    final source = CountedSource();
    final feed = VoiceOverlayFeed(
      sources: [source],
      project: (enabled, _) =>
          VoiceOverlaySnapshot(visible: enabled, members: const []),
    );
    expect(source.registrations, 0);
    feed.setEnabled(true);
    expect(source.registrations, 1);
    feed.setEnabled(true);
    expect(source.registrations, 1);
    feed.setEnabled(false);
    expect(source.registrations, 0);
    feed.setEnabled(true);
    expect(source.registrations, 1);
    feed.dispose();
    expect(source.registrations, 0);
    source.dispose();
  });
}
