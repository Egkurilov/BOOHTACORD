#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>

#import "VideoProcessingAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@interface FlutterScreenShareResolutionProcessor : NSObject <ExternalVideoProcessingDelegate>

- (instancetype)initWithMaximumResolution:(NSInteger)maximumResolution;

@end

NS_ASSUME_NONNULL_END
