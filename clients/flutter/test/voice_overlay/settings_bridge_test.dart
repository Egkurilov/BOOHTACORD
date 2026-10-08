import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/settings/bridge.dart';
import 'package:boohtacord_desktop/src/features/voice/overlay/settings/model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('overlay-settings-test');
  test(
    'configuration reports hotkey conflicts without throwing into voice',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => false);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final bridge = OverlayConfigurationBridge(channel);
      expect(
        await bridge.configure(
          const OverlayConfiguration(enabled: true, hotkey: 119),
        ),
        isFalse,
      );
      bridge.dispose();
    },
  );
  test(
    'late placement from a previous native settings revision is ignored',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => true);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final bridge = OverlayConfigurationBridge(channel);
      var accepted = 0;
      bridge.onPlacement = (_) => accepted++;
      await bridge.configure(const OverlayConfiguration(enabled: true));
      await bridge.receive(
        const MethodCall('placementChanged', {
          'revision': 0,
          'x': .5,
          'y': .5,
          'monitor': 'old',
        }),
      );
      expect(accepted, 0);
      await bridge.receive(
        MethodCall('placementChanged', {
          'revision': bridge.revision,
          'x': .3,
          'y': .4,
          'monitor': 'current',
        }),
      );
      expect(accepted, 1);
      expect(bridge.current.x, .3);
      bridge.dispose();
      await bridge.receive(
        const MethodCall('placementChanged', {'revision': 2, 'x': 0}),
      );
      expect(accepted, 1);
    },
  );
}
