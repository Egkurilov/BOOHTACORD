#include "support.h"

void CheckWindowLifecycle() {
  TestAnchor anchor;
  Check(anchor.window != nullptr, "test anchor creation");
  const HWND foreground = GetForegroundWindow();
  VoiceOverlayWindow overlay;
  Check(overlay.Create(anchor.window), "overlay creation");
  overlay.SetSnapshot(true, {{L"Test participant", true, false}});
  HWND window = OverlayHandle();
  Check(window && IsWindowVisible(window), "visible snapshot");
  Check(GetForegroundWindow() == foreground, "overlay must not steal focus");
  Check((GetWindowLongPtrW(window, GWL_EXSTYLE) & WS_EX_NOACTIVATE) != 0, "non-activating style");
  Check(SendMessageW(window, WM_NCHITTEST, 0, 0) == HTTRANSPARENT, "normal click-through");
  VoiceOverlayConfiguration configuration;
  configuration.scale = 1.5; configuration.opacity = .5;
  configuration.x = 0.3; configuration.y = .4; configuration.monitor = L"DISCONNECTED_MONITOR";
  configuration.editing = true;
  Check(overlay.Configure(configuration), "editor configuration");
  Check(SendMessageW(window, WM_NCHITTEST, 0, 0) == HTCLIENT, "explicit editor accepts pointer");
  Check(SendMessageW(window, WM_MOUSEACTIVATE, 0, 0) == MA_NOACTIVATE, "editor remains non-activating");
  BYTE opacity = 0; DWORD flags = 0; COLORREF color = 0;
  Check(GetLayeredWindowAttributes(window, &color, &opacity, &flags) && opacity == 127, "configured opacity");
  SendMessageW(window, WM_DISPLAYCHANGE, 0, 0);
  MONITORINFO monitor{sizeof(MONITORINFO)}; RECT rect{};
  Check(GetMonitorInfoW(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST), &monitor) &&
    GetWindowRect(window, &rect), "restored monitor geometry");
  Check(rect.left >= monitor.rcWork.left && rect.top >= monitor.rcWork.top &&
    rect.right <= monitor.rcWork.right && rect.bottom <= monitor.rcWork.bottom, "visible work-area clamp");
  configuration.editing = false;
  overlay.Configure(configuration);
  Check(SendMessageW(window, WM_NCHITTEST, 0, 0) == HTTRANSPARENT, "editor exits to click-through");
  overlay.SetSnapshot(false, {});
  Check(OverlayHandle() == nullptr, "disabled overlay releases native window");
  overlay.SetSnapshot(true, {});
  Check(OverlayHandle() != nullptr, "overlay recreates once");
  overlay.Destroy();
  Check(OverlayHandle() == nullptr, "explicit teardown releases window");
}
