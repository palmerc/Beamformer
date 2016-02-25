#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>



@interface VerasonicsFrameMetalProcessor : NSObject
@property (assign, nonatomic) CGFloat centralFrequency;
@property (assign, nonatomic) CGFloat samplingFrequencyHertz;

//- (void)processChannelData:(ComplexVector *)channelData withChannelDelays:(ComplexVector *)channelDelays;

@end
