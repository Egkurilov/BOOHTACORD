#import "BoohtaRnnoiseCaptureDelegate.h"
#include "boohta_rnnoise_capture_processor.h"
#include <memory>
#include <algorithm>
@implementation BoohtaRnnoiseCaptureDelegate {
  std::unique_ptr<boohta::RnnoiseCaptureProcessor> _processor;
}
- (instancetype)init {
  if (self = [super init]) _processor = std::make_unique<boohta::RnnoiseCaptureProcessor>();
  return self;
}
- (BOOL)setEngine:(NSString*)engine {
  boohta::RnnoiseCaptureProcessor::Engine value;
  if (![engine isKindOfClass:[NSString class]] || !boohta::ParseNoiseEngine(engine.UTF8String, &value)) return NO;
  _processor->SetEngine(value);
  return YES;
}
- (void)setControls:(NSDictionary*)settings {
  NSNumber* threshold = settings[@"vadThresholdDb"];
  NSNumber* gain = settings[@"microphoneGainPercent"];
  _processor->controls.Configure(threshold ? threshold.floatValue : -50,
      gain ? gain.floatValue : 100, [settings[@"vad"] boolValue],
      [settings[@"agc"] boolValue], [settings[@"enabled"] boolValue]);
}
- (NSDictionary*)controlsState {
  auto& c = _processor->controls;
  return @{@"status": _processor->sample_rate() == 0 ? @"initializing" :
      !c.supported() ? @"unsupported" : c.applied() ? @"active" : @"initializing",
      @"levelDb": @(c.level_db()), @"clipping": @(c.clipping()), @"gateOpen": @(c.gate_open())};
}
- (NSDictionary*)state {
  const auto requested = _processor->requested_engine();
  const BOOL wantsRnnoise = requested == boohta::RnnoiseCaptureProcessor::Engine::kRnnoise;
  return @{
    @"requestedEngine": @(boohta::NoiseEngineName(requested)),
    @"effectiveEngine": wantsRnnoise ? @"unknown" : @(boohta::NoiseEngineName(requested)),
    @"supported": @NO,
    @"failureReason": wantsRnnoise ? @"platform-aec-ns-coupled" : @"",
    @"processedFrames": @(_processor->processed_frames()),
    @"fallbackFrames": @(_processor->fallback_frames()),
    @"sampleRate": @(_processor->sample_rate()),
    @"channels": @(_processor->channels())
  };
}
- (void)resetState { _processor->Reset(); }
- (void)audioProcessingInitializeWithSampleRate:(size_t)rate channels:(size_t)channels {
  _processor->Initialize((int)rate, (int)channels);
}
- (void)audioProcessingProcess:(RTCAudioBuffer*)buffer {
  // Preserve Apple AEC/NS: RNNoise remains bypassed. Gain/VAD uses fixed
  // 20 ms lookbehind storage and never retains caller buffers or invokes
  // the control channel on this callback.
  // Gain/VAD only: preserve the platform AEC/NS and RNNoise bypass above.
  if (buffer.channels == 0) return;
  _processor->controls.Process([buffer rawBufferForChannel:0], (int)buffer.frames, (int)buffer.frames);
  if (!_processor->controls.supported() && buffer.channels > 1) {
    for (size_t channel = 1; channel < buffer.channels; ++channel)
      std::fill_n([buffer rawBufferForChannel:channel], buffer.frames, 0.f);
  }
}
- (void)audioProcessingRelease { _processor->Reset(); }
@end
