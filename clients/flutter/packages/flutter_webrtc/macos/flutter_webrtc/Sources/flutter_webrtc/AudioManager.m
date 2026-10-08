#import "AudioManager.h"
#import "AudioProcessingAdapter.h"
#import "AudioDeviceChangeMonitor.h"
#import "FlutterWebRTCPlugin.h"

@implementation AudioManager {
  RTCDefaultAudioProcessingModule* _audioProcessingModule;
  AudioProcessingAdapter* _capturePostProcessingAdapter;
  AudioProcessingAdapter* _renderPreProcessingAdapter;
  AudioDeviceChangeMonitor* _deviceChangeMonitor;
}

@synthesize capturePostProcessingAdapter = _capturePostProcessingAdapter;
@synthesize renderPreProcessingAdapter = _renderPreProcessingAdapter;
@synthesize audioProcessingModule = _audioProcessingModule;

+ (instancetype)sharedInstance {
  static dispatch_once_t onceToken;
  static AudioManager* sharedInstance = nil;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  if (self = [super init]) {
    _audioProcessingModule = [[RTCDefaultAudioProcessingModule alloc] init];
    _capturePostProcessingAdapter = [[AudioProcessingAdapter alloc] init];
    _renderPreProcessingAdapter = [[AudioProcessingAdapter alloc] init];
    _rnnoiseCaptureDelegate = [[BoohtaRnnoiseCaptureDelegate alloc] init];
    [_capturePostProcessingAdapter addProcessing:_rnnoiseCaptureDelegate];
    _audioProcessingModule.capturePostProcessingDelegate = _capturePostProcessingAdapter;
    _audioProcessingModule.renderPreProcessingDelegate = _renderPreProcessingAdapter;
    _deviceChangeMonitor = [[AudioDeviceChangeMonitor alloc] initWithHandler:^{
      dispatch_async(dispatch_get_main_queue(), ^{
        FlutterWebRTCPlugin* plugin = FlutterWebRTCPlugin.sharedSingleton;
        if (plugin.eventSink) plugin.eventSink(@{@"event" : @"onDeviceChange"});
      });
    }];
    [_deviceChangeMonitor start];
  }
  return self;
}

- (void)dealloc {
  [_deviceChangeMonitor stop];
  [_capturePostProcessingAdapter removeProcessing:_rnnoiseCaptureDelegate];
}

- (void)addLocalAudioRenderer:(nonnull id<RTCAudioRenderer>)renderer {
  [_capturePostProcessingAdapter addAudioRenderer:renderer];
}

- (void)removeLocalAudioRenderer:(nonnull id<RTCAudioRenderer>)renderer {
  [_capturePostProcessingAdapter removeAudioRenderer:renderer];
}

- (void)addRemoteAudioSink:(nonnull id<RTCAudioRenderer>)sink {
  [_renderPreProcessingAdapter addAudioRenderer:sink];
}

- (void)removeRemoteAudioSink:(nonnull id<RTCAudioRenderer>)sink {
  [_renderPreProcessingAdapter removeAudioRenderer:sink];
}

@end
