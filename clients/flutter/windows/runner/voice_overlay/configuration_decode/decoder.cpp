#include "decoder.h"
#include <windows.h>
#include <cmath>
#include <variant>

namespace {
using flutter::EncodableMap;
using flutter::EncodableValue;
const EncodableValue* Find(const EncodableMap& map, const char* key) {
  const auto found = map.find(EncodableValue(std::string(key)));
  return found == map.end() ? nullptr : &found->second;
}
std::optional<double> Number(const EncodableMap& args, const char* key, double low, double high) {
  const auto* value = Find(args, key);
  if (!value) return std::nullopt;
  double result;
  if (auto* d = std::get_if<double>(value)) result = *d;
  else if (auto* integer32 = std::get_if<int32_t>(value)) result = *integer32;
  else if (auto* integer64 = std::get_if<int64_t>(value)) result = static_cast<double>(*integer64);
  else return std::nullopt;
  return std::isfinite(result) && result >= low && result <= high ?
      std::optional<double>(result) : std::nullopt;
}
}

std::optional<VoiceOverlayConfiguration> DecodeOverlayConfiguration(const flutter::EncodableValue* value) {
  const auto* args = value ? std::get_if<EncodableMap>(value) : nullptr;
  if (!args) return std::nullopt;
  const auto scale = Number(*args, "scale", .75, 2), opacity = Number(*args, "opacity", .25, 1);
  const auto x = Number(*args, "x", 0, 1), y = Number(*args, "y", 0, 1);
  const auto key = Number(*args, "hotkey", 0, 123), mods = Number(*args, "modifiers", 1, 15);
  const auto revision = Number(*args, "revision", 0, 2147483647);
  const auto* editing_value = Find(*args, "editing");
  const auto* editing = editing_value ? std::get_if<bool>(editing_value) : nullptr;
  const auto* monitor_value = Find(*args, "monitor");
  const auto* monitor = monitor_value ? std::get_if<std::string>(monitor_value) : nullptr;
  if (!scale || !opacity || !x || !y || !key || !mods || !revision || !editing || !monitor ||
      monitor->size() > 64 || (*key != 0 && *key < 112) || std::floor(*key) != *key ||
      std::floor(*mods) != *mods || std::floor(*revision) != *revision) return std::nullopt;
  VoiceOverlayConfiguration config;
  config.scale = *scale; config.opacity = *opacity; config.x = *x; config.y = *y;
  config.hotkey = static_cast<unsigned>(*key); config.modifiers = static_cast<unsigned>(*mods);
  config.editing = *editing; config.revision = static_cast<int>(*revision);
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, monitor->data(),
      static_cast<int>(monitor->size()), nullptr, 0);
  if (!monitor->empty() && size <= 0) return std::nullopt;
  config.monitor.resize(size);
  if (size) MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, monitor->data(),
      static_cast<int>(monitor->size()), config.monitor.data(), size);
  return config;
}
