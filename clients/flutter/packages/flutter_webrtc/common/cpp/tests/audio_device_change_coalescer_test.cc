#include <cassert>

#include "audio_device_change_coalescer.h"

int main() {
  flutter_webrtc_plugin::AudioDeviceChangeCoalescer coalescer;
  const auto first = coalescer.schedule();
  const auto second = coalescer.schedule();
  const auto last = coalescer.schedule();

  assert(!coalescer.shouldEmit(first));
  assert(!coalescer.shouldEmit(second));
  assert(coalescer.shouldEmit(last));

  coalescer.cancel();
  assert(!coalescer.shouldEmit(last));
  return 0;
}
