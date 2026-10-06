#ifndef FLUTTER_WEBRTC_AUDIO_DEVICE_SELECTION_H_
#define FLUTTER_WEBRTC_AUDIO_DEVICE_SELECTION_H_

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace flutter_webrtc_plugin {

enum class AudioInputDeviceSelectionStatus {
  kSelected,
  kNotFound,
  kNativeFailure,
};

struct AudioInputDeviceSelectionResult {
  AudioInputDeviceSelectionStatus status;
  std::uint16_t index;
  int native_result;
};

template <typename SelectDevice>
AudioInputDeviceSelectionResult SelectAudioInputDevice(
    const std::vector<std::string>& device_ids,
    const std::string& requested_device_id,
    SelectDevice select_device) {
  if (requested_device_id.empty()) {
    return {AudioInputDeviceSelectionStatus::kNotFound, 0, 0};
  }

  for (std::size_t index = 0; index < device_ids.size(); ++index) {
    if (device_ids[index] != requested_device_id) continue;

    const auto native_result =
        select_device(static_cast<std::uint16_t>(index));
    if (native_result != 0) {
      return {AudioInputDeviceSelectionStatus::kNativeFailure,
              static_cast<std::uint16_t>(index), native_result};
    }
    return {AudioInputDeviceSelectionStatus::kSelected,
            static_cast<std::uint16_t>(index), native_result};
  }

  return {AudioInputDeviceSelectionStatus::kNotFound, 0, 0};
}

}  // namespace flutter_webrtc_plugin

#endif  // FLUTTER_WEBRTC_AUDIO_DEVICE_SELECTION_H_
