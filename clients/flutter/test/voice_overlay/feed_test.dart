import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/feed.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';

void main() {
  test('publishes current projection when an existing voice source changes', () {
    final voice = ChangeNotifier();
    var snapshot = const VoiceOverlaySnapshot(visible: false, members: []);
    final feed = VoiceOverlayFeed(
      sources: [voice],
      project: (_, _) => snapshot,
    );
    feed.setEnabled(true);
    var notifications = 0;
    feed.addListener(() => notifications++);

    snapshot = const VoiceOverlaySnapshot(
      visible: true,
      members: [
        VoiceOverlayMember(
          displayName: 'Alice',
          speaking: true,
          microphoneMuted: false,
        ),
      ],
    );
    voice.notifyListeners();

    expect(notifications, 1);
    expect(feed.snapshot.members.single.displayName, 'Alice');
    expect(feed.snapshot.members.single.speaking, isTrue);
    feed.dispose();
    voice.dispose();
  });

  test('forwards the cleared snapshot on channel or session boundary', () {
    final source = ChangeNotifier();
    var visible = true;
    final feed = VoiceOverlayFeed(
      sources: [source],
      project: (_, _) => VoiceOverlaySnapshot(
        visible: visible,
        members: const [],
      ),
    );

    feed.setEnabled(true);
    visible = false;
    source.notifyListeners();

    expect(feed.snapshot.visible, isFalse);
    expect(feed.snapshot.members, isEmpty);
    feed.dispose();
    source.dispose();
  });

  test('clears participant details before feed shutdown', () {
    final source = ChangeNotifier();
    var visible = true;
    final feed = VoiceOverlayFeed(
      sources: [source],
      project: (_, _) => VoiceOverlaySnapshot(
        visible: visible,
        members: visible
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
    feed.setEnabled(true);
    var notifications = 0;
    feed.addListener(() {
      visible = feed.snapshot.visible;
      notifications++;
    });

    feed.dispose();
    source.notifyListeners();

    expect(feed.snapshot.visible, isFalse);
    expect(feed.snapshot.members, isEmpty);
    expect(notifications, 1);
    source.dispose();
  });
}
