bool reservedVoiceShortcut(
  String code,
  bool control,
  bool alt,
  bool shift,
  bool meta,
) {
  const primary = {
    'KeyR',
    'KeyW',
    'KeyT',
    'KeyN',
    'KeyL',
    'KeyP',
    'KeyF',
    'KeyO',
    'KeyS',
    'KeyD',
    'KeyQ',
    'KeyH',
    'KeyJ',
    'KeyU',
    'KeyB',
    'KeyA',
    'KeyC',
    'KeyX',
    'KeyV',
    'KeyZ',
    'KeyE',
    'KeyI',
    'Tab',
  };
  if ((control || meta) &&
      !alt &&
      (primary.contains(code) || (shift && code == 'KeyM')))
    return true;
  if (meta &&
      !alt &&
      RegExp(r'^(Key[A-Z]|Digit[0-9]|Arrow(Up|Down|Left|Right))$')
          .hasMatch(code))
    return true;
  return alt && ['F4', 'Tab', 'Space'].contains(code) ||
      control && alt && code == 'Delete';
}
