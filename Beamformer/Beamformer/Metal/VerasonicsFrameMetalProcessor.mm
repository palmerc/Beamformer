#import "VerasonicsFrameMetalProcessor.h"

#include <vector>
#include <cmath>

#include "Beamformer.hpp"
#include "ComplexNumbers.hpp"



@implementation VerasonicsFrameMetalProcessor

- (void)processChannelData:(NSArray<NSNumber *> *)channelData withChannelDelays:(NSArray<NSNumber *> *)channelDelays
{
    unsigned long numberOfDelays = channelDelays.count;

    std::vector<int> x_ns;
    std::vector<int> x_n1s;
    std::vector<ComplexF> alphas;
    std::vector<ComplexF> oneMinusAlphas;
    std::vector<float> calculatedDelays;
    std::vector<ComplexF> partAs;
    for (int i = 0; i < numberOfDelays; i++) {
        float channelDelay = [channelDelays[i] floatValue];

        x_ns[i] = floorf(channelDelay);
        x_n1s[i] = ceilf(channelDelay);

        float alpha = x_n1s[i] - channelDelay;
        oneMinusAlphas[i] = ComplexF(1.f - alpha, 0.f);
        alphas[i] = ComplexF(alpha, 0.f);

        float calculatedDelay = 2 * M_PI * self.centralFrequency * channelDelay / self.samplingFrequencyHertz;
        float r = expf(0);
        float real = r * cosf(calculatedDelay);
        float imaginary = -1.f * r * sinf(calculatedDelay);
        partAs[i] = ComplexF(real, imaginary);
    }

    std::vector<ComplexF> complexChannelVector;
    std::vector<ComplexF> complexImageVector = complexImageVectorWithComplexChannelVector(x_ns, x_n1s, alphas, oneMinusAlphas, partAs, complexChannelVector);
}

@end
