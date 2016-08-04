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

inline float2 add(float2 lhs, float2 rhs);
inline float2 subtract(float2 lhs, float2 rhs);
inline float2 multiply(float2 lhs, float2 rhs);
inline float absC(float2 lhs);
inline float decibel(float value);



kernel void processChannelData(const device BeamformerParameters *beamformerParameters [[ buffer(0) ]],
                               const device short2 *IQComplexSampleData [[ buffer(1) ]],
                               const device float2 *IQFrequencyShifts [[ buffer(2) ]],
                               const device float *alphas [[ buffer(3) ]],
                               const device int *sampleIndices [[ buffer(4) ]],
                               device float *imageAmplitudes [[ buffer(5) ]],
                               uint threadIdentifier [[ thread_position_in_grid ]])

{
    int channelCount = beamformerParameters->channelCount; // 128
//    int samplesPerChannel = beamformerParameters->samplesPerChannel; // 400
    int pixelCount = beamformerParameters->pixelCount;

    float2 channelSum(0.f, 0.f);
    for (int channelNumber = 0; channelNumber < channelCount; channelNumber++) {
        uint channelIndex = channelNumber * pixelCount + threadIdentifier;
        int sampleIndex = sampleIndices[channelIndex];

        float2 IQFrequencyShift = IQFrequencyShifts[channelIndex];

        // pull a sample based upon Tau
        float2 lowerSample = static_cast<float2>(IQComplexSampleData[sampleIndex]);
        float2 upperSample = static_cast<float2>(IQComplexSampleData[sampleIndex + 1]);

        float alpha = alphas[channelIndex];
        float2 complexAlpha(alpha, 0.f);
        float2 lowerWeighted = multiply(lowerSample, complexAlpha);

        float oneMinusAlpha = 1.f - alpha;
        float2 complexOneMinusAlpha(oneMinusAlpha, 0.f);
        float2 upperWeighted = multiply(upperSample, complexOneMinusAlpha);

        float2 IQData = add(lowerWeighted, upperWeighted);
        float2 result = multiply(IQFrequencyShift, IQData);
        channelSum = add(channelSum, result);
    }
    float epsilon = 0.01f;
    float absoluteValue = absC(channelSum) + epsilon;
    imageAmplitudes[threadIdentifier] = decibel(absoluteValue);
}

//kernel void findMinMax(const device float *inputImageAmplitudes [[ buffer(0) ]],
//                       device float *inputImageAmplitudes [[ buffer(1) ]],
//                       uint threadIdentifier [[ thread_position_in_grid ]])
//{
//    
//}

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

inline float2 add(float2 lhs, float2 rhs)
{
    return { lhs.x + rhs.x, lhs.y + rhs.y };
}
inline float2 subtract(float2 lhs, float2 rhs)
{
    return { lhs.x - rhs.x, lhs.y - rhs.y };
}
inline float2 multiply(float2 lhs, float2 rhs)
{
    return { lhs.x * rhs.x - lhs.y * rhs.y, lhs.x * rhs.y + rhs.x * lhs.y };
}
inline float absC(float2 lhs)
{
    return sqrt(lhs.x * lhs.x + lhs.y * lhs.y);
}
inline float decibel(float value)
{
    return 20.f * log10(value);
}

