@import Foundation;



@interface VerasonicsFrame : NSObject
@property (assign, nonatomic) NSInteger identifier;
@property (assign, nonatomic) int32_t numberOfChannels;
@property (assign, nonatomic) int32_t numberOfSamplesPerChannel;
@property (assign, nonatomic, readonly) int32_t numberOfSamples;

@property (assign, nonatomic) int16_t *complexSamples;
@property (assign, nonatomic, readonly) NSInteger complexSampleBytes;

@end
