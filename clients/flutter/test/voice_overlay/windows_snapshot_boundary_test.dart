import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/feed.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/projection.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/windows_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'queued stale visible snapshots cannot reappear after disable',
    () async {
      const channel = MethodChannel('overlay-snapshot-boundary');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      final blocked = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (calls.length == 1) await blocked.future;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final source = ChangeNotifier();
      final feed = VoiceOverlayFeed(
        sources: [source],
        project: (enabled, _) =>
            VoiceOverlaySnapshot(visible: enabled, members: const []),
      );
      final client = WindowsVoiceOverlayClient(feed: feed, channel: channel);
      await Future<void>.delayed(Duration.zero);
      feed.setEnabled(true);
      feed.setEnabled(false);
      blocked.complete();
      await client.dispose();
      expect(
        calls.every((call) => (call.arguments as Map)['visible'] == false),
        isTrue,
      );
      feed.dispose();
      source.dispose();
    },
  );
}
