#ifndef RUNNER_VOICE_OVERLAY_WINDOW_H_
#define RUNNER_VOICE_OVERLAY_WINDOW_H_

#include <windows.h>

#include <string>
#include <vector>

struct VoiceOverlayMember {
  std::wstring display_name;
  bool speaking;
  bool microphone_muted;
};

class VoiceOverlayWindow {
 public:
  VoiceOverlayWindow() = default;
  ~VoiceOverlayWindow();

  bool Create(HWND anchor_window);
  void SetSnapshot(bool visible,
                   const std::vector<VoiceOverlayMember>& members);
  void Destroy();

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void Position();
  void Paint();

  HWND window_ = nullptr;
  HWND anchor_window_ = nullptr;
  std::vector<VoiceOverlayMember> members_;
  bool visible_ = false;
};

#endif  // RUNNER_VOICE_OVERLAY_WINDOW_H_
