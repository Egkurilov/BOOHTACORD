import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/feed.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';

void main() {
  test('enabling and disabling recomputes the existing room snapshot', () {
    final source = ChangeNotifier();
    final feed = VoiceOverlayFeed(
      sources: [source],
      project: (enabled, _) => VoiceOverlaySnapshot(
        visible: enabled,
        members: enabled
            ? const [
                VoiceOverlayMember(
                  displayName: 'Alice',
                  speaking: true,
                  microphoneMuted: false,
                ),
              ]
            : const [],
      ),
    );

    expect(feed.snapshot.visible, isFalse);
    feed.setEnabled(true);
    expect(feed.snapshot.visible, isTrue);
    expect(feed.snapshot.members.single.displayName, 'Alice');
    feed.setEnabled(false);
    expect(feed.snapshot.visible, isFalse);
    expect(feed.snapshot.members, isEmpty);
    feed.dispose();
    source.dispose();
  });

}
