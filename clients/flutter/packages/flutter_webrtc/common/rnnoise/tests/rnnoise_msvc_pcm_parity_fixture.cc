// Deterministic DSP fixture for stock/stack-compat compiler parity. The output
// goes only to an explicit test-artifact path, never to repository source.
#include "rnnoise_capture_processor.h"
#include <array>
#include <cmath>
#include <cstdio>
#include <cstdint>
int main(int argc, char** argv) {
  if (argc != 2) return 1;
  FILE* output = std::fopen(argv[1], "wb");
  if (!output) return 2;
  boohta::RnnoiseCaptureProcessor processor;
  processor.Initialize(48000, 1);
  processor.SetEngine(boohta::RnnoiseCaptureProcessor::Engine::kRnnoise);
  uint32_t random = 0x524e4e31;
  for (int block = 0; block < 100; ++block) {
    if (block == 50) processor.Reset();
    std::array<float, 480> frame;
    for (int i = 0; i < 480; ++i) {
      random = random * 1664525u + 1013904223u;
      const float noise = (static_cast<int>(random >> 16) - 32768) * .04f;
      frame[i] = noise + 6000.f * std::sin((block * 480 + i) * .0576f);
    }
    if (!processor.Process(frame.data(), 480, 480)) { std::fclose(output); return 3; }
    if (std::fwrite(frame.data(), sizeof(float), frame.size(), output) != frame.size()) {
      std::fclose(output); return 4;
    }
  }
  return std::fclose(output) == 0 ? 0 : 5;
}
