#import "AudioDeviceChangeMonitor.h"

#import <CoreAudio/AudioHardware.h>

#include "audio_device_change_coalescer.h"

#include <chrono>

namespace {
constexpr auto kQuietPeriod = std::chrono::milliseconds(180);
const AudioObjectPropertyAddress kWatchedProperties[] = {
    {kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal,
     kAudioObjectPropertyElementMain},
    {kAudioHardwarePropertyDefaultInputDevice, kAudioObjectPropertyScopeGlobal,
     kAudioObjectPropertyElementMain},
    {kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal,
     kAudioObjectPropertyElementMain},
};
}

@interface AudioDeviceChangeMonitor ()
@end

@implementation AudioDeviceChangeMonitor {
  dispatch_queue_t _queue;
  AudioDeviceChangeHandler _handler;
  flutter_webrtc_plugin::AudioDeviceChangeCoalescer _coalescer;
  AudioObjectPropertyListenerBlock _listenerBlocks[3];
  UInt32 _registeredCount;
  BOOL _started;
}

- (instancetype)initWithHandler:(AudioDeviceChangeHandler)handler {
  self = [super init];
  if (self) {
    _queue = dispatch_queue_create("boohtacord.audio-device-change", DISPATCH_QUEUE_SERIAL);
    _handler = [handler copy];
  }
  return self;
}

- (BOOL)start {
  __block BOOL wasStarted = NO;
  dispatch_sync(_queue, ^{
    wasStarted = self->_started;
    self->_started = YES;
  });
  if (wasStarted) return YES;

  __weak AudioDeviceChangeMonitor* weakSelf = self;
  UInt32 index = 0;
  for (const auto& property : kWatchedProperties) {
    _listenerBlocks[index] = ^(UInt32, const AudioObjectPropertyAddress[]) {
      [weakSelf signalDeviceChange];
    };
    const OSStatus status = AudioObjectAddPropertyListenerBlock(
        kAudioObjectSystemObject, &property, _queue, _listenerBlocks[index]);
    if (status != noErr) {
      [self stop];
      return NO;
    }
    ++_registeredCount;
    ++index;
  }
  return YES;
}

- (void)stop {
  dispatch_sync(_queue, ^{
    self->_started = NO;
    self->_coalescer.cancel();
  });
  for (UInt32 index = 0; index < _registeredCount; ++index) {
    AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject,
                                          &kWatchedProperties[index], _queue,
                                          _listenerBlocks[index]);
    _listenerBlocks[index] = nil;
  }
  _registeredCount = 0;
}

- (void)signalDeviceChange {
  dispatch_async(_queue, ^{
    if (!self->_started) return;
    const auto token = self->_coalescer.schedule();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kQuietPeriod.count() * NSEC_PER_MSEC),
                   self->_queue, ^{
      if (!self->_started || !self->_coalescer.shouldEmit(token)) return;
      self->_handler();
    });
  });
}

@end
