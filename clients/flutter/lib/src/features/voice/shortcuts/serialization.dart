part of 'model.dart';

Map<String, Object> _encodeBinding(VoiceShortcutBinding binding) => {
  'keyId': binding.keyId,
  'label': binding.label,
  if (binding.physicalKeyId != null) 'physicalKeyId': binding.physicalKeyId!,
  'control': binding.control,
  'alt': binding.alt,
  'shift': binding.shift,
  'meta': binding.meta,
};
VoiceShortcutBinding _decodeBinding(Object? value) {
  if (value is! Map<String, dynamic> ||
      value['keyId'] is! int ||
      value['label'] is! String ||
      (value['physicalKeyId'] != null && value['physicalKeyId'] is! int))
    throw const FormatException('Invalid voice shortcut binding.');
  for (final modifier in ['control', 'alt', 'shift', 'meta']) {
    if (value[modifier] != null && value[modifier] is! bool)
      throw const FormatException('Invalid voice shortcut modifiers.');
  }
  return VoiceShortcutBinding(
    keyId: value['keyId'] as int,
    label: value['label'] as String,
    physicalKeyId: value['physicalKeyId'] as int?,
    control: value['control'] == true,
    alt: value['alt'] == true,
    shift: value['shift'] == true,
    meta: value['meta'] == true,
  );
}
