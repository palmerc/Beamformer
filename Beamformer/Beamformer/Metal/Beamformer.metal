#include <metal_stdlib>
using namespace metal;



struct ImageAmplitudesParameters {
    float minimumValue;
    float maximumValue;
};

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
float decibel(float value);



kernel void processChannelData(const device BeamformerParameters *beamformerParameters [[ buffer(0) ]],
                               const device ComplexNumber *inputChannelData [[ buffer(1) ]],
                               const device ComplexNumber *partAs [[ buffer(2) ]],
                               const device float *alphas [[ buffer(3) ]],
                               const device int *x_ns [[ buffer(4) ]],
                               device float *outputImageAmplitude [[ buffer(5) ]],
                               uint threadIdentifier [[ thread_position_in_grid ]])

{
    int channelCount = beamformerParameters->channelCount; // 128
    int samplesPerChannel = beamformerParameters->samplesPerChannel; // 400
    int xnCutoff = channelCount * samplesPerChannel;

    int pixelCount = beamformerParameters->pixelCount;

    ComplexNumber channelSum = {.real = 0.f, .imaginary = 0.f};
    for (int channelNumber = 0; channelNumber < channelCount; channelNumber++) {
        uint channelIndex = channelNumber * pixelCount + threadIdentifier;

        int xnIndex = x_ns[channelIndex];
        int xn1Index = xnIndex + 1;

        if (xnIndex > -1 && xn1Index < xnCutoff) {
            ComplexNumber partA = partAs[channelIndex];
            ComplexNumber lower = inputChannelData[xnIndex];
            ComplexNumber upper = inputChannelData[xn1Index];

            float alpha = alphas[channelIndex];
            ComplexNumber complexAlpha = {.real = alpha, .imaginary = 0.f};
            lower = multiply(lower, complexAlpha);

            float oneMinusAlpha = 1.f - alpha;
            ComplexNumber complexOneMinusAlpha = {.real = oneMinusAlpha, .imaginary = 0.f};
            upper = multiply(upper, complexOneMinusAlpha);

            ComplexNumber partB = add(lower, upper);
            ComplexNumber result = multiply(partA, partB);
            channelSum = add(channelSum, result);
        }
    }
    float epsilon = 0.01f;
    float absoluteValue = absC(channelSum) + epsilon;
    outputImageAmplitude[threadIdentifier] = decibel(absoluteValue);
}

kernel void processDecibelValues(const device ImageAmplitudesParameters *imageParameters [[ buffer(0) ]],
                                 const device float *inputImageAmplitudes [[ buffer(1) ]],
                                 device unsigned char *outputImageAmplitudes [[ buffer(2) ]],
                                 uint threadIdentifier [[ thread_position_in_grid ]])
{
//    float minimumValue = imageParameters->minimumValue;
    float maximumValue = imageParameters->maximumValue;

    float decibelValue = inputImageAmplitudes[threadIdentifier];
    float shiftedDecibelValue = decibelValue - maximumValue;
    float dynamicRange = 60.f;
    if (shiftedDecibelValue < -dynamicRange) {
        shiftedDecibelValue = -dynamicRange;
    }
    float scaledValue = 255.f / dynamicRange * (shiftedDecibelValue + dynamicRange);
    outputImageAmplitudes[threadIdentifier] = static_cast<unsigned char>(scaledValue);
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
float decibel(float value)
{
    return 20.f * log10(value);
}

