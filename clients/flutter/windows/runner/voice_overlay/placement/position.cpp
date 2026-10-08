#include "../../voice_overlay_window.h"
#include <algorithm>
#include <cstddef>

namespace {
struct MonitorSelection { std::wstring name; HMONITOR monitor = nullptr; };
BOOL CALLBACK SelectMonitor(HMONITOR monitor, HDC, LPRECT, LPARAM data) {
  auto* selected = reinterpret_cast<MonitorSelection*>(data);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (GetMonitorInfoW(monitor, &info) && selected->name == info.szDevice)
    selected->monitor = monitor;
  return TRUE;
}
}

void VoiceOverlayWindow::Position() {
  if (!window_) return;
  MonitorSelection selected{configuration_.monitor};
  EnumDisplayMonitors(nullptr, nullptr, SelectMonitor,
                      reinterpret_cast<LPARAM>(&selected));
  HMONITOR monitor = selected.monitor ? selected.monitor :
      MonitorFromWindow(anchor_window_, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!GetMonitorInfoW(monitor, &info)) return;
  const RECT work = info.rcWork;
  const int width = std::min(Layout(288), static_cast<int>(work.right - work.left));
  const int height = std::min(Layout(48 + 34 *
      static_cast<int>(std::max<std::size_t>(1, members_.size()))),
      static_cast<int>(work.bottom - work.top));
  const int dx = static_cast<int>(work.right - work.left) - width;
  const int dy = static_cast<int>(work.bottom - work.top) - height;
  const int x = work.left + static_cast<int>(dx * configuration_.x);
  const int y = work.top + static_cast<int>(dy * configuration_.y);
  SetWindowPos(window_, HWND_TOPMOST, x, y, width, height,
      SWP_NOACTIVATE | ((visible_ && !hotkey_hidden_) ? SWP_SHOWWINDOW : SWP_HIDEWINDOW));
}

void VoiceOverlayWindow::EndDrag() {
  dragging_ = false;
  ReleaseCapture();
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  HMONITOR monitor = MonitorFromWindow(window_, MONITOR_DEFAULTTONEAREST);
  RECT rect{};
  if (!GetMonitorInfoW(monitor, &info) || !GetWindowRect(window_, &rect)) return;
  configuration_.monitor = info.szDevice;
  const int dx = static_cast<int>(info.rcWork.right - info.rcWork.left - (rect.right - rect.left));
  const int dy = static_cast<int>(info.rcWork.bottom - info.rcWork.top - (rect.bottom - rect.top));
  configuration_.x = dx <= 0 ? 0 : std::clamp((rect.left - info.rcWork.left) / static_cast<double>(dx), 0.0, 1.0);
  configuration_.y = dy <= 0 ? 0 : std::clamp((rect.top - info.rcWork.top) / static_cast<double>(dy), 0.0, 1.0);
  Position();
  if (placement_changed) placement_changed(configuration_);
}
