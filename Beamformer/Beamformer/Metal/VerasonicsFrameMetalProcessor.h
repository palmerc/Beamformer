#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>



@interface VerasonicsFrameMetalProcessor : NSObject
@property (assign, nonatomic) CGFloat centralFrequency;
@property (assign, nonatomic) CGFloat samplingFrequencyHertz;

- (NSArray<NSNumber *> *)processChannelData:(NSArray<NSNumber *> *)channelData withChannelDelays:(NSArray<NSNumber *> *)channelDelays;
@end
