@import Foundation;



@interface VerasonicsFrame : NSObject
@property (assign, nonatomic) NSInteger identifier;
@property (assign, nonatomic) NSTimeInterval timestamp;
@property (assign, nonatomic) double lensCorrection;
@property (assign, nonatomic) double samplingFrequency;
@property (assign, nonatomic) int32_t numberOfChannels;
@property (assign, nonatomic) int32_t numberOfSamplesPerChannel;
@property (strong, nonatomic) NSData *complexSamples;

@property (assign, nonatomic, readonly) int32_t numberOfSamples;

@end