#include "voice_overlay_channel.h"

#include <windows.h>

#include <optional>
#include <string>
#include <utility>
#include <variant>

#include <flutter/standard_method_codec.h>

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  const auto found = map.find(EncodableValue(std::string(key)));
  return found == map.end() ? nullptr : &found->second;
}

std::optional<std::wstring> ToWideName(const std::string& value) {
  if (value.empty() || value.size() > 256) return std::nullopt;
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                       value.data(), static_cast<int>(value.size()),
                                       nullptr, 0);
  if (size <= 0) return std::nullopt;
  std::wstring wide(size, L'\0');
  if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
                           static_cast<int>(value.size()), wide.data(), size)) {
    return std::nullopt;
  }
  if (wide.size() > 128) wide.resize(128);
  if (!wide.empty() && wide.back() >= 0xD800 && wide.back() <= 0xDBFF) {
    wide.pop_back();
  }
  return wide;
}

void HideOnError(VoiceOverlayWindow* window,
                 flutter::MethodResult<EncodableValue>* result) {
  window->SetSnapshot(false, {});
  result->Error("invalid_arguments", "Overlay snapshot is malformed.");
}
}  // namespace

VoiceOverlayChannel::VoiceOverlayChannel(flutter::BinaryMessenger* messenger,
                                         VoiceOverlayWindow* window)
    : window_(window),
      channel_(std::make_unique<flutter::MethodChannel<EncodableValue>>(
          messenger, "boohtacord/voice_overlay",
          &flutter::StandardMethodCodec::GetInstance())) {
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleCall(call, std::move(result));
      });
}

VoiceOverlayChannel::~VoiceOverlayChannel() {
  channel_->SetMethodCallHandler(nullptr);
}

void VoiceOverlayChannel::HandleCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  if (call.method_name() != "setSnapshot") {
    result->NotImplemented();
    return;
  }
  const auto* arguments = call.arguments()
                              ? std::get_if<EncodableMap>(call.arguments())
                              : nullptr;
  const auto* visible_value = arguments ? Find(*arguments, "visible") : nullptr;
  const auto* visible = visible_value ? std::get_if<bool>(visible_value) : nullptr;
  if (!visible) {
    HideOnError(window_, result.get());
    return;
  }
  if (!*visible) {
    window_->SetSnapshot(false, {});
    result->Success();
    return;
  }

  const auto* members_value = Find(*arguments, "members");
  const auto* members = members_value ? std::get_if<flutter::EncodableList>(members_value)
                                      : nullptr;
  if (!members || members->size() > 12) {
    HideOnError(window_, result.get());
    return;
  }
  std::vector<VoiceOverlayMember> projected;
  projected.reserve(members->size());
  for (const auto& item : *members) {
    const auto* member = std::get_if<EncodableMap>(&item);
    if (!member) {
      HideOnError(window_, result.get());
      return;
    }
    const auto* name_value = Find(*member, "displayName");
    const auto* speaking_value = Find(*member, "speaking");
    const auto* muted_value = Find(*member, "microphoneMuted");
    const auto* name = name_value ? std::get_if<std::string>(name_value) : nullptr;
    const auto* speaking = speaking_value ? std::get_if<bool>(speaking_value) : nullptr;
    const auto* muted = muted_value ? std::get_if<bool>(muted_value) : nullptr;
    const auto wide_name = name ? ToWideName(*name) : std::nullopt;
    if (!wide_name || !speaking || !muted) {
      HideOnError(window_, result.get());
      return;
    }
    projected.push_back({*wide_name, *speaking, *muted});
  }
  window_->SetSnapshot(true, projected);
  result->Success();
}
