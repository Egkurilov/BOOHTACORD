import 'package:flutter/services.dart';

import 'model.dart';

enum ShortcutCaptureKind { wait, navigate, cancel, clear, assign }

class ShortcutCapture {
  const ShortcutCapture(this.kind, [this.binding]);
  final ShortcutCaptureKind kind;
  final VoiceShortcutBinding? binding;
}

ShortcutCapture captureVoiceShortcut(
  KeyEvent event,
  HardwareKeyboard keyboard,
) {
  if (event is! KeyDownEvent)
    return const ShortcutCapture(ShortcutCaptureKind.wait);
  if (event.logicalKey == LogicalKeyboardKey.tab)
    return const ShortcutCapture(ShortcutCaptureKind.navigate);
  if (event.logicalKey == LogicalKeyboardKey.escape)
    return const ShortcutCapture(ShortcutCaptureKind.cancel);
  if (event.logicalKey == LogicalKeyboardKey.backspace ||
      event.logicalKey == LogicalKeyboardKey.delete)
    return const ShortcutCapture(ShortcutCaptureKind.clear);
  if (isVoiceShortcutModifierKey(event.logicalKey))
    return const ShortcutCapture(ShortcutCaptureKind.wait);
  return ShortcutCapture(
    ShortcutCaptureKind.assign,
    VoiceShortcutBinding.fromEvent(event, keyboard),
  );
}
