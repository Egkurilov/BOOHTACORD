#include <jni.h>
#include "rnnoise_capture_processor.h"
static boohta::RnnoiseCaptureProcessor* Processor(jlong handle) {
  return reinterpret_cast<boohta::RnnoiseCaptureProcessor*>(handle);
}
extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeSetControls(
    JNIEnv*, jclass, jlong handle, jdouble threshold, jdouble percent,
    jboolean vad, jboolean agc, jboolean enabled) {
  if (handle) Processor(handle)->controls.Configure(threshold, percent, vad, agc, enabled);
}
extern "C" JNIEXPORT jdoubleArray JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeControlsState(JNIEnv* env, jclass, jlong handle) {
  if (!handle) return nullptr;
  auto* p = Processor(handle);
  auto& c = p->controls;
  jdouble values[] = {c.supported() ? 1. : 0., c.applied() ? 1. : 0.,
      c.level_db(), c.clipping() ? 1. : 0., c.gate_open() ? 1. : 0., static_cast<double>(p->sample_rate())};
  auto result = env->NewDoubleArray(6);
  if (result) env->SetDoubleArrayRegion(result, 0, 6, values);
  return result;
}
extern "C" JNIEXPORT void JNICALL
Java_com_cloudwebrtc_webrtc_audio_RnnoiseCaptureAdapter_nativeProcessControls(
    JNIEnv* env, jclass, jlong handle, jint frames, jobject buffer) {
  if (!handle) return;
  auto* pcm = buffer ? static_cast<float*>(env->GetDirectBufferAddress(buffer)) : nullptr;
  const auto bytes = buffer ? env->GetDirectBufferCapacity(buffer) : 0;
  if (reinterpret_cast<uintptr_t>(pcm) % alignof(float) != 0) pcm = nullptr;
  Processor(handle)->controls.Process(pcm, frames, bytes >= 0 ? static_cast<int>(bytes / sizeof(float)) : 0);
}
