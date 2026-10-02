/* BOOHTACORD wrapper. PCM uses RNNoise's native float/16-bit scale. */
#include <string.h>
#include "rnnoise.h"
static float input_frame[480];
static float output_frame[480];
static unsigned char state_storage[65536] __attribute__((aligned(16)));
int ns_init(void) {
  if (rnnoise_get_size() > sizeof(state_storage)) return 0;
  memset(state_storage, 0, sizeof(state_storage));
  rnnoise_init((DenoiseState *)state_storage);
  memset(input_frame, 0, sizeof(input_frame));
  memset(output_frame, 0, sizeof(output_frame));
  /* Upstream initializes FFT tables lazily on first frame. Warm off callback. */
  rnnoise_process_frame((DenoiseState *)state_storage, output_frame, input_frame);
  rnnoise_init((DenoiseState *)state_storage);
  memset(output_frame, 0, sizeof(output_frame));
  return 1;
}
void ns_reset(void) {
  rnnoise_init((DenoiseState *)state_storage);
  memset(input_frame, 0, sizeof(input_frame));
  memset(output_frame, 0, sizeof(output_frame));
}
float *ns_input(void) { return input_frame; }
float *ns_output(void) { return output_frame; }
float ns_process(void) { return rnnoise_process_frame((DenoiseState *)state_storage, output_frame, input_frame); }
