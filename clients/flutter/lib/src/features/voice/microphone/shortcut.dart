import 'package:flutter/services.dart';

class VoiceShortcutBinding {
  const VoiceShortcutBinding({
    required this.keyId,
    required this.label,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  final int keyId;
  final String label;
  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;

  bool get hasModifier => control || alt || shift || meta;

  bool get isValid {
    if (keyId == 0 || label.trim().isEmpty || _modifierIds.contains(keyId)) return false;
    return hasModifier || !RegExp(r'^[A-Za-z0-9]$').hasMatch(label);
  }

  bool matches(KeyEvent event, HardwareKeyboard keyboard) =>
      event.logicalKey.keyId == keyId &&
      keyboard.isControlPressed == control &&
      keyboard.isAltPressed == alt &&
      keyboard.isShiftPressed == shift &&
      keyboard.isMetaPressed == meta;

  Map<String, Object> toJson() => {
    'keyId': keyId,
    'label': label,
    'control': control,
    'alt': alt,
    'shift': shift,
    'meta': meta,
  };

  factory VoiceShortcutBinding.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['keyId'] is! int || value['label'] is! String) {
      throw const FormatException('Invalid voice shortcut binding.');
    }
    return VoiceShortcutBinding(
      keyId: value['keyId'] as int,
      label: value['label'] as String,
      control: value['control'] == true,
      alt: value['alt'] == true,
      shift: value['shift'] == true,
      meta: value['meta'] == true,
    );
  }

  @override
  bool operator ==(Object other) => other is VoiceShortcutBinding &&
      other.keyId == keyId && other.control == control && other.alt == alt && other.shift == shift && other.meta == meta;

  @override
  int get hashCode => Object.hash(keyId, control, alt, shift, meta);
}

final Set<int> _modifierIds = {
  LogicalKeyboardKey.controlLeft.keyId, LogicalKeyboardKey.controlRight.keyId,
  LogicalKeyboardKey.altLeft.keyId, LogicalKeyboardKey.altRight.keyId,
  LogicalKeyboardKey.shiftLeft.keyId, LogicalKeyboardKey.shiftRight.keyId,
  LogicalKeyboardKey.metaLeft.keyId, LogicalKeyboardKey.metaRight.keyId,
};

String formatVoiceShortcut(VoiceShortcutBinding? binding) {
  if (binding == null) return 'Не назначено';
  final modifiers = <String>[
    if (binding.control) 'Ctrl',
    if (binding.alt) 'Alt',
    if (binding.shift) 'Shift',
    if (binding.meta) 'Meta',
  ];
  return [...modifiers, binding.label].join('+');
}

String? voiceShortcutConflict(VoiceShortcutBinding binding, VoiceShortcutBinding? other, int? pttKeyId) {
  if (other == binding) return 'duplicate';
  if (pttKeyId == binding.keyId) return 'ptt';
  if ((binding.control || binding.meta) && !binding.alt && !binding.shift && binding.keyId == LogicalKeyboardKey.keyK.keyId) return 'search';
  return null;
}
