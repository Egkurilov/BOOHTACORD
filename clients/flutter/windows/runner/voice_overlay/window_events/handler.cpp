#include "../../voice_overlay_window.h"

LRESULT CALLBACK VoiceOverlayWindow::WindowProc(HWND window, UINT message,
                                                WPARAM wparam, LPARAM lparam) {
  auto* self = reinterpret_cast<VoiceOverlayWindow*>(GetWindowLongPtrW(window, GWLP_USERDATA));
  if (message == WM_NCCREATE) {
    auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    self = static_cast<VoiceOverlayWindow*>(create->lpCreateParams);
    SetWindowLongPtrW(window, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
    self->window_ = window;
  }
  return self ? self->HandleMessage(message, wparam, lparam)
              : DefWindowProcW(window, message, wparam, lparam);
}

LRESULT VoiceOverlayWindow::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_MOUSEACTIVATE: return MA_NOACTIVATE;
    case WM_NCHITTEST:
      if (!configuration_.editing) return HTTRANSPARENT;
      return HTCLIENT;
    case WM_HOTKEY:
      hotkey_hidden_ = !hotkey_hidden_;
      if (hotkey_hidden_) {
        dragging_ = false;
        ReleaseCapture();
        configuration_.editing = false;
        SetWindowLongPtrW(window_, GWL_EXSTYLE,
            GetWindowLongPtrW(window_, GWL_EXSTYLE) | WS_EX_TRANSPARENT);
        if (placement_changed) placement_changed(configuration_);
      }
      UpdateVisibility();
      return 0;
    case WM_LBUTTONDOWN:
      if (configuration_.editing) {
        dragging_ = true;
        GetCursorPos(&drag_origin_);
        RECT rect{}; GetWindowRect(window_, &rect);
        window_origin_ = {rect.left, rect.top};
        SetCapture(window_);
      }
      return 0;
    case WM_MOUSEMOVE:
      if (dragging_) {
        POINT cursor{}; GetCursorPos(&cursor);
        SetWindowPos(window_, HWND_TOPMOST, window_origin_.x + cursor.x - drag_origin_.x,
          window_origin_.y + cursor.y - drag_origin_.y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
      }
      return 0;
    case WM_LBUTTONUP:
      if (dragging_) EndDrag();
      return 0;
    case WM_CAPTURECHANGED: dragging_ = false; return 0;
    case WM_DISPLAYCHANGE:
      Position(); InvalidateRect(window_, nullptr, TRUE); return 0;
    case WM_DPICHANGED:
      if (dragging_) {
        const RECT* rect = reinterpret_cast<const RECT*>(lparam);
        SetWindowPos(window_, HWND_TOPMOST, rect->left, rect->top,
            rect->right - rect->left, rect->bottom - rect->top, SWP_NOACTIVATE);
      } else Position();
      InvalidateRect(window_, nullptr, TRUE); return 0;
    case WM_ERASEBKGND: return 1;
    case WM_PAINT: Paint(); return 0;
    default: return DefWindowProcW(window_, message, wparam, lparam);
  }
}
