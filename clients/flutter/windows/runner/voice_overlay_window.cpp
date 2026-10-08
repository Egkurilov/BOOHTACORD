#include "voice_overlay_window.h"

#include <algorithm>
#include <cstddef>

namespace {
constexpr wchar_t kClassName[] = L"BOOHTACORD_VOICE_OVERLAY";
constexpr int kWidth = 288;
constexpr int kRowHeight = 34;
constexpr int kMargin = 16;
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
  SetLayeredWindowAttributes(window_, 0, 232, LWA_ALPHA);
  Position();
  return true;
}

void VoiceOverlayWindow::SetSnapshot(
    bool visible, const std::vector<VoiceOverlayMember>& members) {
  visible_ = visible;
  members_ = visible ? members : std::vector<VoiceOverlayMember>{};
  if (!window_) return;
  if (!visible_) {
    ShowWindow(window_, SW_HIDE);
    return;
  }
  Position();
  SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
  InvalidateRect(window_, nullptr, TRUE);
}

void VoiceOverlayWindow::Destroy() {
  if (window_) DestroyWindow(window_);
  window_ = nullptr;
  members_.clear();
  visible_ = false;
}

LRESULT CALLBACK VoiceOverlayWindow::WindowProc(HWND window, UINT message,
                                                WPARAM wparam, LPARAM lparam) {
  auto* self = reinterpret_cast<VoiceOverlayWindow*>(
      GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    self = static_cast<VoiceOverlayWindow*>(create->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(self));
    self->window_ = window;
  }
  return self ? self->HandleMessage(message, wparam, lparam)
              : DefWindowProcW(window, message, wparam, lparam);
}

LRESULT VoiceOverlayWindow::HandleMessage(UINT message, WPARAM wparam,
                                           LPARAM lparam) {
  switch (message) {
    case WM_MOUSEACTIVATE:
      return MA_NOACTIVATE;
    case WM_NCHITTEST:
      return HTTRANSPARENT;
    case WM_DISPLAYCHANGE:
    case WM_DPICHANGED:
      Position();
      InvalidateRect(window_, nullptr, TRUE);
      return 0;
    case WM_ERASEBKGND:
      return 1;
    case WM_PAINT:
      Paint();
      return 0;
    default:
      return DefWindowProcW(window_, message, wparam, lparam);
  }
}

void VoiceOverlayWindow::Position() {
  HMONITOR monitor = MonitorFromWindow(anchor_window_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!GetMonitorInfoW(monitor, &info)) return;
  const RECT work = info.rcWork;
  const int width = std::min(kWidth, work.right - work.left);
  const int height = std::min(
      48 + kRowHeight *
               static_cast<int>(std::max<std::size_t>(1, members_.size())),
      work.bottom - work.top);
  const int x = std::clamp(work.right - width - kMargin, work.left,
                           work.right - width);
  const int y = std::clamp(work.top + kMargin, work.top, work.bottom - height);
  SetWindowPos(window_, HWND_TOPMOST, x, y, width, height,
               SWP_NOACTIVATE | (visible_ ? SWP_SHOWWINDOW : SWP_HIDEWINDOW));
}
