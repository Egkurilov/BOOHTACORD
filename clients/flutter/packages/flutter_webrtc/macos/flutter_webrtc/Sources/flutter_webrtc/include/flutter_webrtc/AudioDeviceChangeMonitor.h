#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^AudioDeviceChangeHandler)(void);

@interface AudioDeviceChangeMonitor : NSObject
- (instancetype)initWithHandler:(AudioDeviceChangeHandler)handler;
- (BOOL)start;
- (void)stop;
- (void)signalDeviceChange;
@end

NS_ASSUME_NONNULL_END
