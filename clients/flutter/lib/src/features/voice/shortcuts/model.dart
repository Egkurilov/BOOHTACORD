import 'package:flutter/services.dart';

import 'physical_code.dart';
import 'reserved.dart';
part 'policy.dart';
part 'serialization.dart';

class VoiceShortcutBinding {
  const VoiceShortcutBinding({
    required this.keyId,
    required this.label,
    this.physicalKeyId,
    this.control = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
  });

  final int keyId;
  final int? physicalKeyId;
  String get code => physicalKeyId == null
      ? legacyKeyCode(keyId, label)
      : physicalKeyCode(physicalKeyId!);
  final String label;
  final bool control;
  final bool alt;
  final bool shift;
  final bool meta;

  bool get hasModifier => control || alt || shift || meta;

  bool get isValid => _validBinding(this);

  bool matches(KeyEvent event, HardwareKeyboard keyboard) =>
      (physicalKeyId == null
          ? event.logicalKey.keyId == keyId
          : event.physicalKey.usbHidUsage == physicalKeyId) &&
      keyboard.isControlPressed == control &&
      keyboard.isAltPressed == alt &&
      keyboard.isShiftPressed == shift &&
      keyboard.isMetaPressed == meta;

  factory VoiceShortcutBinding.fromEvent(
    KeyEvent event,
    HardwareKeyboard keyboard,
  ) => VoiceShortcutBinding(
    keyId: event.logicalKey.keyId,
    physicalKeyId: event.physicalKey.usbHidUsage,
    label: physicalKeyCode(event.physicalKey.usbHidUsage),
    control: keyboard.isControlPressed,
    alt: keyboard.isAltPressed,
    shift: keyboard.isShiftPressed,
    meta: keyboard.isMetaPressed,
  );
  Map<String, Object> toJson() => _encodeBinding(this);
  factory VoiceShortcutBinding.fromJson(Object? value) => _decodeBinding(value);

  @override
  bool operator ==(Object other) =>
      other is VoiceShortcutBinding &&
      (other.physicalKeyId == physicalKeyId &&
          (physicalKeyId != null || other.keyId == keyId)) &&
      other.control == control &&
      other.alt == alt &&
      other.shift == shift &&
      other.meta == meta;

  @override
  int get hashCode => Object.hash(
    physicalKeyId,
    physicalKeyId == null ? keyId : 0,
    control,
    alt,
    shift,
    meta,
  );
}
