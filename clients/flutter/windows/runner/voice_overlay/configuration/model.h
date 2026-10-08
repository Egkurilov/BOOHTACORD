#pragma once
#include <string>

struct VoiceOverlayConfiguration {
  double scale = 1.0, opacity = .91, x = 1.0, y = 0.0;
  std::wstring monitor;
  unsigned hotkey = 0, modifiers = 6;
  int revision = 0;
  bool editing = false;
};
