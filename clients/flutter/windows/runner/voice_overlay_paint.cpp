#include "voice_overlay_window.h"

namespace {
constexpr int kRowHeight = 34;
}

void VoiceOverlayWindow::Paint() {
  PAINTSTRUCT ps{};
  HDC dc = BeginPaint(window_, &ps);
  RECT bounds{};
  GetClientRect(window_, &bounds);
  HBRUSH background = CreateSolidBrush(RGB(24, 26, 34));
  FillRect(dc, &bounds, background);
  DeleteObject(background);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(242, 244, 250));
  HGDIOBJ previous = SelectObject(dc, GetStockObject(DEFAULT_GUI_FONT));
  RECT header{16, 8, bounds.right - 16, 38};
  DrawTextW(dc, L"BOOHTACORD  •  VOICE", -1, &header,
            DT_LEFT | DT_VCENTER | DT_SINGLELINE);
  int y = 44;
  for (const auto& member : members_) {
    RECT row{8, y, bounds.right - 8, y + kRowHeight - 3};
    HBRUSH fill = CreateSolidBrush(member.speaking ? RGB(55, 82, 73)
                                                   : RGB(38, 41, 51));
    FillRect(dc, &row, fill);
    DeleteObject(fill);
    SetTextColor(dc, member.speaking ? RGB(166, 246, 192) : RGB(235, 237, 244));
    RECT name{18, y, bounds.right - 78, y + kRowHeight - 3};
    DrawTextW(dc, member.display_name.c_str(), -1, &name,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
    RECT state{bounds.right - 74, y, bounds.right - 14, y + kRowHeight - 3};
    DrawTextW(dc, member.microphone_muted ? L"MIC OFF" : L"MIC ON", -1,
              &state, DT_RIGHT | DT_VCENTER | DT_SINGLELINE);
    y += kRowHeight;
  }
  if (members_.empty()) {
    RECT empty{16, y, bounds.right - 16, y + kRowHeight};
    SetTextColor(dc, RGB(180, 184, 196));
    DrawTextW(dc, L"Нет активных участников", -1, &empty,
              DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);
  }
  SelectObject(dc, previous);
  EndPaint(window_, &ps);
}
