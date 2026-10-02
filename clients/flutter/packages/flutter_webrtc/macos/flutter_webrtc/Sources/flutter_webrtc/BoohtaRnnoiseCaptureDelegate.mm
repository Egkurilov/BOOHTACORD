#import "BoohtaRnnoiseCaptureDelegate.h"
#include "boohta_rnnoise_capture_processor.h"
#include <memory>
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
  // This is a writable hook, but bypass intentionally preserves Apple's AEC
  // and avoids stacking RNNoise with the coupled hardware NS. No PCM is copied
  // or retained and no control channel runs on this callback.
  (void)buffer;
}
- (void)audioProcessingRelease { _processor->Reset(); }
@end
