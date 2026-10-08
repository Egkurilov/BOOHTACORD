#include "../../voice_overlay_channel.h"
#include <flutter/standard_method_codec.h>
#include "../snapshot_decode/decoder.h"
#include "../configuration_decode/decoder.h"

using flutter::EncodableMap;
using flutter::EncodableValue;

VoiceOverlayChannel::VoiceOverlayChannel(flutter::BinaryMessenger* messenger,
                                         VoiceOverlayWindow* window)
    : window_(window),
      channel_(std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "boohtacord/voice_overlay", &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleCall(call, std::move(result));
  });
  window_->placement_changed = [this](const VoiceOverlayConfiguration& value) {
    const int size = WideCharToMultiByte(CP_UTF8, 0, value.monitor.data(),
        static_cast<int>(value.monitor.size()), nullptr, 0, nullptr, nullptr);
    std::string monitor(size, '\0');
    if (size) WideCharToMultiByte(CP_UTF8, 0, value.monitor.data(),
        static_cast<int>(value.monitor.size()), monitor.data(), size, nullptr, nullptr);
    channel_->InvokeMethod("placementChanged", std::make_unique<EncodableValue>(EncodableMap{
      {EncodableValue("revision"), EncodableValue(value.revision)},
      {EncodableValue("x"), EncodableValue(value.x)},
      {EncodableValue("y"), EncodableValue(value.y)},
      {EncodableValue("monitor"), EncodableValue(monitor)},
      {EncodableValue("editing"), EncodableValue(value.editing)},
    }));
  };
  window_->shortcut_error = [this](int revision) {
    channel_->InvokeMethod("hotkeyConflict", std::make_unique<EncodableValue>(
      EncodableMap{{EncodableValue("revision"), EncodableValue(revision)}}));
  };
}

VoiceOverlayChannel::~VoiceOverlayChannel() {
  window_->placement_changed = nullptr;
  window_->shortcut_error = nullptr;
  channel_->SetMethodCallHandler(nullptr);
}

void VoiceOverlayChannel::HandleCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (call.method_name() == "setConfiguration") {
    const auto config = DecodeOverlayConfiguration(call.arguments());
    if (!config) {
      result->Error("invalid_configuration", "Overlay configuration is malformed.");
      return;
    }
    result->Success(EncodableValue(window_->Configure(*config)));
    return;
  }
  if (call.method_name() != "setSnapshot") { result->NotImplemented(); return; }
  const auto snapshot = DecodeOverlaySnapshot(call.arguments());
  if (!snapshot) {
    window_->SetSnapshot(false, {});
    result->Error("invalid_arguments", "Overlay snapshot is malformed.");
    return;
  }
  window_->SetSnapshot(snapshot->visible, snapshot->members);
  result->Success();
}
