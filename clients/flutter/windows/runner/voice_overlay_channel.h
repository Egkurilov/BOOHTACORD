#ifndef RUNNER_VOICE_OVERLAY_CHANNEL_H_
#define RUNNER_VOICE_OVERLAY_CHANNEL_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>

#include <memory>

#include "voice_overlay_window.h"

class VoiceOverlayChannel {
 public:
  VoiceOverlayChannel(flutter::BinaryMessenger* messenger,
                      VoiceOverlayWindow* window);
  ~VoiceOverlayChannel();

 private:
  void HandleCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  VoiceOverlayWindow* window_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_VOICE_OVERLAY_CHANNEL_H_
