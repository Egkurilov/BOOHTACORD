#import <Foundation/Foundation.h>
#import "AudioProcessingAdapter.h"
NS_ASSUME_NONNULL_BEGIN
// Installed once in AudioManager. Apple's default VPIO couples AEC/NS, so
// native RNNoise remains unsupported until an independent route has evidence.
@interface BoohtaRnnoiseCaptureDelegate : NSObject <ExternalAudioProcessingDelegate>
- (BOOL)setEngine:(NSString*)engine;
- (NSDictionary*)state;
- (void)resetState;
@end
NS_ASSUME_NONNULL_END
