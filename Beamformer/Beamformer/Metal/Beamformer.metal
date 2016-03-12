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

float2 add(float2 lhs, float2 rhs);
float2 subtract(float2 lhs, float2 rhs);
float2 multiply(float2 lhs, float2 rhs);
float absC(float2 lhs);
float decibel(float value);



kernel void processChannelData(const device BeamformerParameters *beamformerParameters [[ buffer(0) ]],
                               const device float2 *inputChannelData [[ buffer(1) ]],
                               const device float2 *partAs [[ buffer(2) ]],
                               const device float *alphas [[ buffer(3) ]],
                               const device int *x_ns [[ buffer(4) ]],
                               device float *outputImageAmplitude [[ buffer(5) ]],
                               uint threadIdentifier [[ thread_position_in_grid ]])

{
    int channelCount = beamformerParameters->channelCount; // 128
    int samplesPerChannel = beamformerParameters->samplesPerChannel; // 400
    int xnCutoff = channelCount * samplesPerChannel;

    int pixelCount = beamformerParameters->pixelCount;

    float2 channelSum(0.f, 0.f);
    for (int channelNumber = 0; channelNumber < channelCount; channelNumber++) {
        uint channelIndex = channelNumber * pixelCount + threadIdentifier;

        int xnIndex = x_ns[channelIndex];
        int xn1Index = xnIndex + 1;

        if (xnIndex > -1 && xn1Index < xnCutoff) {
            float2 partA = partAs[channelIndex];
            float2 lower = inputChannelData[xnIndex];
            float2 upper = inputChannelData[xn1Index];

            float alpha = alphas[channelIndex];
            float2 complexAlpha(alpha, 0.f);
            lower = multiply(lower, complexAlpha);

            float oneMinusAlpha = 1.f - alpha;
            float2 complexOneMinusAlpha(oneMinusAlpha, 0.f);
            upper = multiply(upper, complexOneMinusAlpha);

            float2 partB = add(lower, upper);
            float2 result = multiply(partA, partB);
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

float2 add(float2 lhs, float2 rhs)
{
    return { lhs.x + rhs.x, lhs.y + rhs.y };
}
float2 subtract(float2 lhs, float2 rhs)
{
    return { lhs.x - rhs.x, lhs.y - rhs.y };
}
float2 multiply(float2 lhs, float2 rhs)
{
    return { lhs.x * rhs.x - lhs.y * rhs.y, lhs.x * rhs.y + rhs.x * lhs.y };
}
float absC(float2 lhs)
{
    return sqrt(pow(lhs.x, 2) + pow(lhs.y, 2));
}
float decibel(float value)
{
    return 20.f * log10(value);
}

