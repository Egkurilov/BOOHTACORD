#include "../../voice_overlay_window.h"

#include <algorithm>
#include <cstddef>

namespace {
constexpr wchar_t kClassName[] = L"BOOHTACORD_VOICE_OVERLAY";
constexpr int kWidth = 288;
}
VoiceOverlayWindow::~VoiceOverlayWindow() { Destroy(); }

bool VoiceOverlayWindow::Create(HWND anchor_window) {
  anchor_window_ = anchor_window;
  HINSTANCE instance = GetModuleHandleW(nullptr);
  WNDCLASSEXW cls{};
  cls.cbSize = sizeof(cls);
  if (!GetClassInfoExW(instance, kClassName, &cls)) {
    cls.style = CS_HREDRAW | CS_VREDRAW;
    cls.lpfnWndProc = WindowProc;
    cls.hInstance = instance;
    cls.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    cls.lpszClassName = kClassName;
    if (!RegisterClassExW(&cls)) return false;
  }
  window_ = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_LAYERED | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE |
          WS_EX_TRANSPARENT,
      kClassName, L"BOOHTACORD voice overlay", WS_POPUP, 0, 0, kWidth, 80,
      nullptr, nullptr, instance, this);
  if (!window_) return false;
  Configure(configuration_);
  Position();
  return true;
}

void VoiceOverlayWindow::SetSnapshot(
    bool visible, const std::vector<VoiceOverlayMember>& members) {
  visible_ = visible;
  members_ = visible ? members : std::vector<VoiceOverlayMember>{};
  if (!visible_) {
    Destroy();
    return;
  }
  if (!window_ && !Create(anchor_window_)) return;
  Position();
  RegisterShortcut();
  UpdateVisibility();
  InvalidateRect(window_, nullptr, TRUE);
}

void VoiceOverlayWindow::Destroy() {
  if (shortcut_registered_ && window_) UnregisterHotKey(window_, 1);
  shortcut_registered_ = false;
  shortcut_failed_ = false;
  dragging_ = false;
  configuration_.editing = false;
  hotkey_hidden_ = false;
  if (window_) DestroyWindow(window_);
  window_ = nullptr;
  members_.clear();
  visible_ = false;
}
