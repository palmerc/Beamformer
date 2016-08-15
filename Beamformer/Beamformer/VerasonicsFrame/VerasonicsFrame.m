#import "VerasonicsFrame.h"



@interface VerasonicsFrame ()
@end



@implementation VerasonicsFrame
- (instancetype)init
{
    self = [super init];
    if (self) {
        _identifier = -1;
        _timestamp = 0.f;
        _lensCorrection = 0.f;
        _samplingFrequency = 0.f;
        _numberOfChannels = 0;
        _numberOfSamplesPerChannel = 0;
    }

    return self;
}

- (int32_t)numberOfSamples
{
    return self.numberOfChannels * self.numberOfSamplesPerChannel;
}

@end
