#include "support.h"

void CheckHotkeyBehavior() {
  TestAnchor anchor;
  VoiceOverlayWindow overlay;
  Check(overlay.Create(anchor.window), "hotkey overlay creation");
  overlay.SetSnapshot(true, {{L"Test participant", true, false}});
  unsigned chosen = 0;
  constexpr unsigned modifiers = MOD_CONTROL | MOD_SHIFT | MOD_ALT | MOD_WIN;
  for (unsigned key = VK_F1; key <= VK_F12; key++) {
    if (RegisterHotKey(anchor.window, 99, modifiers | MOD_NOREPEAT, key)) { chosen = key; break; }
  }
  Check(chosen != 0, "a free test combination is required");
  bool reported = false;
  overlay.shortcut_error = [&](int) { reported = true; };
  VoiceOverlayConfiguration configuration;
  configuration.hotkey = chosen; configuration.modifiers = modifiers;
  Check(!overlay.Configure(configuration) && reported, "real OS registration conflict must be reported");
  UnregisterHotKey(anchor.window, 99);
  Check(overlay.Configure(configuration), "retry after releasing conflict");
  HWND window = OverlayHandle();
  SendMessageW(window, WM_HOTKEY, 1, 0);
  Check(!IsWindowVisible(window), "hotkey hides overlay");
  overlay.SetSnapshot(true, {{L"Another participant", false, true}});
  Check(!IsWindowVisible(window), "live snapshots cannot undo hotkey hiding");
  SendMessageW(window, WM_HOTKEY, 1, 0);
  Check(IsWindowVisible(window), "hotkey shows overlay");
  overlay.SetSnapshot(false, {});
  Check(RegisterHotKey(anchor.window, 99, modifiers | MOD_NOREPEAT, chosen) != FALSE,
    "disconnect unregisters overlay hotkey");
  UnregisterHotKey(anchor.window, 99);
}
