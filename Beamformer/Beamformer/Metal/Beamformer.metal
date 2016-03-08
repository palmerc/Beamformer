#include <metal_stdlib>
using namespace metal;


struct BeamformerParameters {
    int channelCount;
    int samplesPerChannel;
    int pixelCount;
};

struct ComplexNumber {
    float real;
    float imaginary;
};

ComplexNumber add(ComplexNumber lhs, ComplexNumber rhs);
ComplexNumber subtract(ComplexNumber lhs, ComplexNumber rhs);
ComplexNumber multiply(ComplexNumber lhs, ComplexNumber rhs);
float absC(ComplexNumber lhs);



kernel void processChannelData(const device BeamformerParameters *beamformerParameters [[ buffer(0) ]],
                               const device ComplexNumber *inputChannelData [[ buffer(1) ]],
                               const device ComplexNumber *partAs [[ buffer(2) ]],
                               const device float *alphas [[ buffer(3) ]],
                               const device int *x_ns [[ buffer(4) ]],
                               device float *outputChannelData [[ buffer(5) ]],
                               uint threadIdentifier [[ thread_position_in_grid ]])

{
    int channelCount = beamformerParameters[0].channelCount; // 128
    int samplesPerChannel = beamformerParameters[0].samplesPerChannel; // 400
    int xnCutoff = channelCount * samplesPerChannel;

    int pixelCount = beamformerParameters[0].pixelCount;

    ComplexNumber channelSum = {.real = 0.0, .imaginary = 0.0};
    for (int channelNumber = 0; channelNumber < channelCount; channelNumber++) {
        uint channelIndex = channelNumber * pixelCount + threadIdentifier;

        int xnIndex = x_ns[channelIndex];
        int xn1Index = xnIndex + 1;

        if (xnIndex > -1 && xn1Index < xnCutoff) {
            ComplexNumber partA = partAs[channelIndex];
            ComplexNumber lower = inputChannelData[xnIndex];
            ComplexNumber upper = inputChannelData[xn1Index];

            float alpha = alphas[channelIndex];
            ComplexNumber complexAlpha = {.real = alpha, .imaginary = 0.0};
            lower = multiply(lower, complexAlpha);

            float oneMinusAlpha = 1.0 - alpha;
            ComplexNumber complexOneMinusAlpha = {.real = oneMinusAlpha, .imaginary = 0.0};
            upper = multiply(upper, complexOneMinusAlpha);

            ComplexNumber partB = add(lower, upper);
            ComplexNumber result = multiply(partA, partB);
            channelSum = add(channelSum, result);
        }
    }
    float absoluteValue = absC(channelSum);
    outputChannelData[threadIdentifier] = absoluteValue;
}

ComplexNumber add(ComplexNumber lhs, ComplexNumber rhs)
{
    return { lhs.real + rhs.real, lhs.imaginary + rhs.imaginary };
}
ComplexNumber subtract(ComplexNumber lhs, ComplexNumber rhs)
{
    return { lhs.real - rhs.real, lhs.imaginary - rhs.imaginary };
}
ComplexNumber multiply(ComplexNumber lhs, ComplexNumber rhs)
{
    return { lhs.real * rhs.real - lhs.imaginary * rhs.imaginary, lhs.real * rhs.imaginary + rhs.real * lhs.imaginary };
}
float absC(ComplexNumber lhs)
{
    return sqrt(pow(lhs.real, 2) + pow(lhs.imaginary, 2));
}
