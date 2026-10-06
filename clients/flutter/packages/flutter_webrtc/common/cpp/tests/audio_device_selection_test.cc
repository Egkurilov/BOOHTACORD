#include <cassert>
#include <cstdint>
#include <string>
#include <vector>

#include "audio_device_selection.h"

using flutter_webrtc_plugin::AudioInputDeviceSelectionStatus;
using flutter_webrtc_plugin::SelectAudioInputDevice;

int main() {
  const std::vector<std::string> devices = {"default", "input-two"};
  int call_count = 0;
  std::uint16_t selected_index = 99;

  const auto selected = SelectAudioInputDevice(
      devices, "input-two", [&](std::uint16_t index) {
        ++call_count;
        selected_index = index;
        return 0;
      });
  assert(selected.status == AudioInputDeviceSelectionStatus::kSelected);
  assert(selected.index == 1);
  assert(selected.native_result == 0);
  assert(call_count == 1);
  assert(selected_index == 1);

  const auto failed = SelectAudioInputDevice(
      devices, "input-two", [](std::uint16_t) { return -7; });
  assert(failed.status == AudioInputDeviceSelectionStatus::kNativeFailure);
  assert(failed.native_result == -7);

  call_count = 0;
  const auto missing = SelectAudioInputDevice(
      devices, "missing", [&](std::uint16_t) {
        ++call_count;
        return 0;
      });
  assert(missing.status == AudioInputDeviceSelectionStatus::kNotFound);
  assert(call_count == 0);
  return 0;
}
