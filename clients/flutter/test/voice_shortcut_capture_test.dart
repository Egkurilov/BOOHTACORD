import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:boohtacord_desktop/src/features/voice/shortcuts/model.dart';
import 'package:boohtacord_desktop/src/features/voice/shortcuts/capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('new capture keeps physical code and old bindings remain readable', () {
    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyM,
      logicalKey: LogicalKeyboardKey.keyQ,
      timeStamp: Duration.zero,
    );
    final binding = VoiceShortcutBinding.fromEvent(
      event,
      HardwareKeyboard.instance,
    );
    expect(binding.physicalKeyId, PhysicalKeyboardKey.keyM.usbHidUsage);
    expect(binding.code, 'KeyM');
    expect(binding.isValid, isFalse);
    expect(
      VoiceShortcutBinding.fromJson(binding.toJson()).physicalKeyId,
      binding.physicalKeyId,
    );
    final old = VoiceShortcutBinding.fromJson({
      'keyId': LogicalKeyboardKey.keyM.keyId,
      'label': 'M',
      'control': true,
    });
    expect(old.isValid, isTrue);
  });
  test('capture handles navigation, clear, cancel and repeat', () {
    KeyEvent event(LogicalKeyboardKey key) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.tab,
      logicalKey: key,
      timeStamp: Duration.zero,
    );
    expect(
      captureVoiceShortcut(
        event(LogicalKeyboardKey.tab),
        HardwareKeyboard.instance,
      ).kind,
      ShortcutCaptureKind.navigate,
    );
    expect(
      captureVoiceShortcut(
        event(LogicalKeyboardKey.escape),
        HardwareKeyboard.instance,
      ).kind,
      ShortcutCaptureKind.cancel,
    );
    expect(
      captureVoiceShortcut(
        event(LogicalKeyboardKey.delete),
        HardwareKeyboard.instance,
      ).kind,
      ShortcutCaptureKind.clear,
    );
    expect(
      captureVoiceShortcut(
        KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.keyM,
          logicalKey: LogicalKeyboardKey.keyM,
          timeStamp: Duration.zero,
        ),
        HardwareKeyboard.instance,
      ).kind,
      ShortcutCaptureKind.wait,
    );
  });

  testWidgets(
    'capture and matching use the physical key under a different layout',
    (tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      const event = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.keyM,
        logicalKey: LogicalKeyboardKey.keyQ,
        timeStamp: Duration.zero,
      );
      final binding = VoiceShortcutBinding.fromEvent(
        event,
        HardwareKeyboard.instance,
      );
      expect(binding.control, isTrue);
      expect(binding.code, 'KeyM');
      expect(binding.isValid, isTrue);
      expect(binding.matches(event, HardwareKeyboard.instance), isTrue);
      expect(formatVoiceShortcut(binding), 'Ctrl+M');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    },
  );
}
