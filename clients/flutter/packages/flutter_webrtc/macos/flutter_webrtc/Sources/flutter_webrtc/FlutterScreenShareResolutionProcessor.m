#import "FlutterScreenShareResolutionProcessor.h"

#import "FlutterRTCFrameCapturer.h"

@import CoreImage;
@import CoreVideo;

@implementation FlutterScreenShareResolutionProcessor {
  NSInteger _maximumResolution;
  CIContext *_context;
}

- (instancetype)initWithMaximumResolution:(NSInteger)maximumResolution {
  self = [super init];
  if (self) {
    _maximumResolution = MAX(0, maximumResolution);
    _context = [CIContext contextWithOptions:nil];
  }
  return self;
}

- (RTCVideoFrame *)onFrame:(RTCVideoFrame *)frame {
  NSInteger sourceLongEdge = MAX(frame.width, frame.height);
  if (_maximumResolution <= 0 || sourceLongEdge <= _maximumResolution) {
    return frame;
  }

  CGFloat scale = (CGFloat)_maximumResolution / sourceLongEdge;
  size_t width = MAX(2, ((size_t)(frame.width * scale)) & ~((size_t)1));
  size_t height = MAX(2, ((size_t)(frame.height * scale)) & ~((size_t)1));
  CVPixelBufferRef sourceBuffer =
      [FlutterRTCFrameCapturer convertToCVPixelBuffer:frame];
  if (sourceBuffer == nil) {
    return frame;
  }

  CVPixelBufferRef outputBuffer = nil;
  NSDictionary *attributes = @{
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    (id)kCVPixelBufferCGImageCompatibilityKey : @YES,
    (id)kCVPixelBufferCGBitmapContextCompatibilityKey : @YES,
  };
  CVReturn status = CVPixelBufferCreate(
      kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
      (__bridge CFDictionaryRef)attributes, &outputBuffer);
  if (status != kCVReturnSuccess || outputBuffer == nil) {
    CVPixelBufferRelease(sourceBuffer);
    return frame;
  }

  CIImage *inputImage = [CIImage imageWithCVPixelBuffer:sourceBuffer];
  CGFloat actualScaleX = (CGFloat)width / frame.width;
  CGFloat actualScaleY = (CGFloat)height / frame.height;
  CIImage *scaledImage = [inputImage imageByApplyingTransform:
      CGAffineTransformMakeScale(actualScaleX, actualScaleY)];
  CGRect outputBounds = CGRectMake(0, 0, width, height);
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  [_context render:scaledImage
   toCVPixelBuffer:outputBuffer
            bounds:outputBounds
        colorSpace:colorSpace];
  CGColorSpaceRelease(colorSpace);

  RTCCVPixelBuffer *buffer =
      [[RTCCVPixelBuffer alloc] initWithPixelBuffer:outputBuffer];
  RTCVideoFrame *scaledFrame = [[RTCVideoFrame alloc]
      initWithBuffer:buffer
            rotation:frame.rotation
         timeStampNs:frame.timeStampNs];
  CVPixelBufferRelease(outputBuffer);
  CVPixelBufferRelease(sourceBuffer);
  return scaledFrame;
}

@end
