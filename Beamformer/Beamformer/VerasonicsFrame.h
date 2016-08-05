@import Foundation;



@interface VerasonicsFrame : NSObject
@property (assign, nonatomic) NSInteger identifier;
@property (assign, nonatomic) NSInteger timestamp;
@property (assign, nonatomic) int32_t numberOfChannels;
@property (assign, nonatomic) int32_t numberOfSamplesPerChannel;
@property (assign, nonatomic, readonly) int32_t numberOfSamples;

@property (strong, nonatomic) NSData *complexSamples;
@property (assign, nonatomic, readonly) NSInteger complexSampleBytes;

@end
