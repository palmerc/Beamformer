#import "VerasonicsFrame.h"



@interface VerasonicsFrame ()
@end



@implementation VerasonicsFrame
- (instancetype)init
{
    self = [super init];
    if (self) {
        _identifier = -1;
        _numberOfChannels = 0;
        _numberOfSamplesPerChannel = 0;
    }

    return self;
}

- (int32_t)numberOfSamples
{
    return self.numberOfChannels * self.numberOfSamplesPerChannel;
}

- (NSInteger)complexSampleBytes
{
    return self.numberOfSamples * 2 * sizeof(int16_t);
}

@end
