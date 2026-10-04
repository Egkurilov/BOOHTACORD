part of 'model.dart';

bool _validBinding(VoiceShortcutBinding binding) {
  if (binding.keyId == 0 ||
      binding.label.trim().isEmpty ||
      _modifierIds.contains(binding.keyId))
    return false;
  if ([
    'Tab',
    'Escape',
    'Backspace',
    'Delete',
    'Enter',
    'Space',
    'F5',
    'F11',
    'F12',
  ].contains(binding.code))
    return false;
  if (binding.code.startsWith('USB')) return false;
  if (binding.physicalKeyId != null &&
      PhysicalKeyboardKey.findKeyByCode(binding.physicalKeyId!) == null)
    return false;
  if (!binding.hasModifier &&
      RegExp(r'^(Key[A-Z]|Digit[0-9]|Numpad[0-9])$').hasMatch(binding.code))
    return false;
  return binding.hasModifier ||
      !RegExp(r'^[A-Za-z0-9]$').hasMatch(binding.label);
}

final Set<int> _modifierIds = {
  LogicalKeyboardKey.controlLeft.keyId,
  LogicalKeyboardKey.controlRight.keyId,
  LogicalKeyboardKey.altLeft.keyId,
  LogicalKeyboardKey.altRight.keyId,
  LogicalKeyboardKey.shiftLeft.keyId,
  LogicalKeyboardKey.shiftRight.keyId,
  LogicalKeyboardKey.metaLeft.keyId,
  LogicalKeyboardKey.metaRight.keyId,
};

bool isVoiceShortcutModifierKey(LogicalKeyboardKey key) =>
    _modifierIds.contains(key.keyId);

String formatVoiceShortcut(VoiceShortcutBinding? binding) {
  if (binding == null) return 'Не назначено';
  final modifiers = <String>[
    if (binding.control) 'Ctrl',
    if (binding.alt) 'Alt',
    if (binding.shift) 'Shift',
    if (binding.meta) 'Meta',
  ];
  return [
    ...modifiers,
    binding.physicalKeyId == null
        ? binding.label
        : binding.code
              .replaceFirst(RegExp(r'^Key|^Digit'), '')
              .replaceFirst('Numpad', 'Num '),
  ].join('+');
}

String? voiceShortcutConflict(
  VoiceShortcutBinding binding,
  VoiceShortcutBinding? other,
  int? pttKeyId,
) {
  if (other != null &&
      other.code == binding.code &&
      other.control == binding.control &&
      other.alt == binding.alt &&
      other.shift == binding.shift &&
      other.meta == binding.meta)
    return 'duplicate';
  if (pttKeyId == binding.keyId ||
      (pttKeyId != null && legacyKeyCode(pttKeyId, '') == binding.code))
    return 'ptt';
  if ((binding.control || binding.meta) &&
      (binding.code == 'KeyK' ||
          binding.keyId == LogicalKeyboardKey.keyK.keyId))
    return 'search';
  if (reservedVoiceShortcut(
    binding.code,
    binding.control,
    binding.alt,
    binding.shift,
    binding.meta,
  ))
    return 'reserved';
  return null;
}
