#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
#import "AudioProcessingAdapter.h"
#import "BoohtaRnnoiseCaptureDelegate.h"

@interface AudioManager : NSObject

@property(nonatomic, strong) RTCDefaultAudioProcessingModule* _Nonnull audioProcessingModule;

@property(nonatomic, strong) AudioProcessingAdapter* _Nonnull capturePostProcessingAdapter;

@property(nonatomic, strong) AudioProcessingAdapter* _Nonnull renderPreProcessingAdapter;

@property(nonatomic, strong) BoohtaRnnoiseCaptureDelegate* _Nonnull rnnoiseCaptureDelegate;

+ (_Nonnull instancetype)sharedInstance;

- (void)addLocalAudioRenderer:(nonnull id<RTCAudioRenderer>)renderer;

- (void)removeLocalAudioRenderer:(nonnull id<RTCAudioRenderer>)renderer;

@end
