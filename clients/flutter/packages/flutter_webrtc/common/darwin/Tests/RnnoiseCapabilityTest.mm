#import "BoohtaRnnoiseCaptureDelegate.h"
#include <cassert>
int main() {
  @autoreleasepool {
    BoohtaRnnoiseCaptureDelegate* processor = [[BoohtaRnnoiseCaptureDelegate alloc] init];
    assert(![processor setEngine:@"invalid"]);
    assert([processor setEngine:@"rnnoise"]);
    [processor audioProcessingInitializeWithSampleRate:48000 channels:1];
    NSDictionary* state = [processor state];
    assert([state[@"requestedEngine"] isEqual:@"rnnoise"]);
    assert([state[@"effectiveEngine"] isEqual:@"unknown"]);
    assert(![state[@"supported"] boolValue]);
    assert([state[@"failureReason"] isEqual:@"platform-aec-ns-coupled"]);
    assert([state[@"processedFrames"] unsignedLongLongValue] == 0);
    assert([processor setEngine:@"browser"]);
    assert([[processor state][@"effectiveEngine"] isEqual:@"browser"]);
    [processor resetState];
    assert([processor setEngine:@"off"]);
    assert([[processor state][@"effectiveEngine"] isEqual:@"off"]);
  }
}
