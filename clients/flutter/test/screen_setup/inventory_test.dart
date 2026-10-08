import 'package:boohtacord_desktop/src/features/screen/setup/select_source/inventory.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter_test/flutter_test.dart';

import 'source_support.dart';

void main() {
  test(
    'late screen inventory cannot replace newer selected window inventory',
    () async {
      final native = FakeDesktopCapturer();
      final inventory = SourceInventory(enabled: true, capturer: native);
      inventory.start();
      inventory.selectType(rtc.SourceType.Window);
      final window = FakeSource('window', rtc.SourceType.Window);
      native.calls.last.complete([window]);
      await Future<void>.delayed(Duration.zero);
      inventory.select(window.id);
      native.calls.first.complete([
        FakeSource('screen', rtc.SourceType.Screen),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(inventory.selected, same(window));
      expect(inventory.sources.keys, ['window']);
      inventory.dispose();
      await native.close();
    },
  );
  test(
    'disposing source picker ignores late sources and cancels subscriptions',
    () async {
      final native = FakeDesktopCapturer();
      final inventory = SourceInventory(enabled: true, capturer: native);
      inventory.start();
      inventory.dispose();
      native.calls.single.complete([
        FakeSource('screen', rtc.SourceType.Screen),
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(inventory.sources, isEmpty);
      expect(inventory.refreshTimer!.isActive, isFalse);
      expect(native.onAdded.hasListener, isFalse);
      await native.close();
    },
  );
}
