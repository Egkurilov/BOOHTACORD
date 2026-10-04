import 'package:flutter/services.dart';

String physicalKeyCode(int usage) {
  final key = usage & 0xffff;
  if (usage >= 0x70004 && usage <= 0x7001d)
    return 'Key${String.fromCharCode(65 + key - 4)}';
  if (usage >= 0x7001e && usage <= 0x70026) return 'Digit${key - 0x1d}';
  if (usage == 0x70027) return 'Digit0';
  if (usage >= 0x7003a && usage <= 0x70045) return 'F${key - 0x39}';
  if (usage >= 0x70068 && usage <= 0x70073) return 'F${key - 0x67 + 12}';
  if (usage >= 0x70059 && usage <= 0x70061) return 'Numpad${key - 0x58}';
  if (usage == 0x70062) return 'Numpad0';
  const names = {
    0x54: 'NumpadDivide',
    0x55: 'NumpadMultiply',
    0x56: 'NumpadSubtract',
    0x57: 'NumpadAdd',
    0x63: 'NumpadDecimal',
    0x67: 'NumpadEqual',
    0x85: 'NumpadComma',
    0x28: 'Enter',
    0x29: 'Escape',
    0x2a: 'Backspace',
    0x2b: 'Tab',
    0x2c: 'Space',
    0x2d: 'Minus',
    0x2e: 'Equal',
    0x2f: 'BracketLeft',
    0x30: 'BracketRight',
    0x31: 'Backslash',
    0x33: 'Semicolon',
    0x34: 'Quote',
    0x35: 'Backquote',
    0x36: 'Comma',
    0x37: 'Period',
    0x38: 'Slash',
    0x49: 'Insert',
    0x4a: 'Home',
    0x4b: 'PageUp',
    0x4c: 'Delete',
    0x4d: 'End',
    0x4e: 'PageDown',
    0x4f: 'ArrowRight',
    0x50: 'ArrowLeft',
    0x51: 'ArrowDown',
    0x52: 'ArrowUp',
  };
  return names[key] ?? 'USB${usage.toRadixString(16)}';
}

String legacyKeyCode(int keyId, String label) {
  if (keyId >= 97 && keyId <= 122)
    return 'Key${String.fromCharCode(keyId - 32)}';
  if (keyId >= 48 && keyId <= 57) return 'Digit${String.fromCharCode(keyId)}';
  const named = {
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.enter: 'Enter',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.f4: 'F4',
    LogicalKeyboardKey.f5: 'F5',
    LogicalKeyboardKey.f11: 'F11',
    LogicalKeyboardKey.f12: 'F12',
  };
  for (final entry in named.entries) {
    if (entry.key.keyId == keyId) return entry.value;
  }
  return label;
}
