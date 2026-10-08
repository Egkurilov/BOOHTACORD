#include "../../voice_overlay_window.h"
#include <algorithm>

bool VoiceOverlayWindow::Configure(const VoiceOverlayConfiguration& value) {
  if (shortcut_registered_ && window_) UnregisterHotKey(window_, 1);
  shortcut_registered_ = false;
  shortcut_failed_ = false;
  configuration_ = value;
  if (!window_) return true;
  LONG_PTR style = GetWindowLongPtrW(window_, GWL_EXSTYLE);
  style = configuration_.editing ? style & ~WS_EX_TRANSPARENT
                                 : style | WS_EX_TRANSPARENT;
  SetWindowLongPtrW(window_, GWL_EXSTYLE, style);
  SetLayeredWindowAttributes(window_, 0,
      static_cast<BYTE>(configuration_.opacity * 255), LWA_ALPHA);
  Position();
  InvalidateRect(window_, nullptr, TRUE);
  return RegisterShortcut();
}

bool VoiceOverlayWindow::RegisterShortcut() {
  if (!window_ || !visible_ || configuration_.hotkey == 0) return true;
  if (shortcut_failed_) return false;
  if (shortcut_registered_) return true;
  shortcut_registered_ = RegisterHotKey(window_, 1,
      configuration_.modifiers | MOD_NOREPEAT, configuration_.hotkey) != FALSE;
  if (!shortcut_registered_) {
    shortcut_failed_ = true;
    if (shortcut_error) shortcut_error(configuration_.revision);
  }
  return shortcut_registered_;
}

void VoiceOverlayWindow::UpdateVisibility() {
  if (!window_) return;
  if (!visible_ || hotkey_hidden_) ShowWindow(window_, SW_HIDE);
  else SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
      SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
}

int VoiceOverlayWindow::Layout(int dip) const {
  const UINT dpi = window_ ? GetDpiForWindow(window_) : 96;
  return static_cast<int>(dip * configuration_.scale * dpi / 96.0);
}
