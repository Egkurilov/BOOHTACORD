import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/feed.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';

void main() {
  test('changing speaker filter recomputes the visible roster', () {
    final source = ChangeNotifier();
    final feed = VoiceOverlayFeed(
      sources: [source],
      project: (enabled, onlySpeakers) => VoiceOverlaySnapshot(
        visible: enabled,
        members: enabled
            ? [
                const VoiceOverlayMember(
                  displayName: 'Alice',
                  speaking: true,
                  microphoneMuted: false,
                ),
                if (!onlySpeakers)
                  const VoiceOverlayMember(
                    displayName: 'Bob',
                    speaking: false,
                    microphoneMuted: false,
                  ),
              ]
            : const [],
      ),
    );
    feed.setEnabled(true);
    expect(feed.snapshot.members, hasLength(2));

    feed.setOnlySpeakers(true);

    expect(feed.snapshot.members.map((member) => member.displayName), ['Alice']);
    feed.dispose();
    source.dispose();
  });
}
