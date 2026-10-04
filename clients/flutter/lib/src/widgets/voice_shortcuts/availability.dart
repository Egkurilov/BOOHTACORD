class ShortcutAvailability {
  bool foreground = true;
  bool hardwareKeyboard = false;
  bool enabled({required bool mobile}) =>
      foreground && (!mobile || hardwareKeyboard);
  void setForeground(bool value, {required bool mobile}) {
    foreground = value;
    if (!value && mobile) hardwareKeyboard = false;
  }

  void observeHardwareKey() {
    if (foreground) hardwareKeyboard = true;
  }
}
