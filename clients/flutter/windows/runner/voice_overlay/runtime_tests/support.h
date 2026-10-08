#pragma once
#include "../../voice_overlay_window.h"
#include <stdexcept>

inline void Check(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}
struct TestAnchor {
  HWND window = CreateWindowExW(0, L"STATIC", L"BOOHTACORD overlay test anchor",
    WS_OVERLAPPEDWINDOW, 0, 0, 500, 300, nullptr, nullptr, GetModuleHandleW(nullptr), nullptr);
  ~TestAnchor() { if (window) DestroyWindow(window); }
};
inline HWND OverlayHandle() {
  HWND result = nullptr;
  EnumThreadWindows(GetCurrentThreadId(), [](HWND window, LPARAM data) -> BOOL {
    wchar_t name[64]{}; GetClassNameW(window, name, 64);
    if (std::wstring(name) == L"BOOHTACORD_VOICE_OVERLAY")
      *reinterpret_cast<HWND*>(data) = window;
    return TRUE;
  }, reinterpret_cast<LPARAM>(&result));
  return result;
}
void CheckWindowLifecycle();
void CheckHotkeyBehavior();
void CheckDecoders();
