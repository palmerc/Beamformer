#include <metal_stdlib>
#include <metal_math>

using namespace metal;



struct ProbeParameters {
    int angleCount;
    int channelCount;
    int samplesPerChannel;
    float samplingFrequencyHz;
    float centralFrequencyHz;
    float lensCorrection;
    float elementSpacingInMillimeters;
};

struct ProcessingParameters {
    float speedOfSoundInMillimetersPerSecond;
    float fNumber;
    float imageStartXInMillimeters;
    float imageStartZInMillimeters;
    float maximumValue;
    float dynamicRange;
};

typedef struct {
    packed_float2 position;
    packed_float2 texCoords;
} VertexIn;

typedef struct {
    float4 position [[ position ]];
    float2 texCoords;
} FragmentVertex;

#define M_PI 3.14159265358979323846264338327950288 // Pi, π - everone's favorite irrational number

inline float2 addC(float2 lhs, float2 rhs);
inline float2 subtractC(float2 lhs, float2 rhs);
inline float2 multiplyC(float2 lhs, float2 rhs);
inline float2 divideC(float2 lhs, float2 rhs);
inline float2 conjugateC(float2 lhs);
inline float absC(float2 lhs);
inline float decibel(float value);


vertex FragmentVertex basicVertex(device VertexIn *vertexArray [[ buffer(0) ]],
                                  uint vertexIndex [[ vertex_id ]])
{
    VertexIn in = vertexArray[vertexIndex];
    
    FragmentVertex out;
    out.position = float4(in.position, 0.f, 1.f);
    out.texCoords = in.texCoords;
    
    return out;
}

fragment half4 basicFragment(FragmentVertex in [[ stage_in ]],
                             texture2d<uint, access::sample> texture [[ texture(0) ]])
{
    constexpr sampler nearestSampler(coord::normalized, filter::nearest);
    half3 intensity = half3(texture.sample(nearestSampler, in.texCoords).r / 255.h);
    half4 color = half4(intensity, 1.h);
    
    return color;
}

kernel void processChannelData(texture2d<ushort, access::write> outputTexture [[ texture(0) ]],
                               constant ProbeParameters *probeParameters [[ buffer(0) ]],
                               constant ProcessingParameters *processingParameters [[ buffer(1) ]],
                               constant float *anglesInRadians [[ buffer(2) ]],
                               constant int2 *IQComplexSampleData [[ buffer(3) ]],
                               uint threadIdentifier [[ thread_position_in_grid ]])

{
    const float samplingFrequencyHz = probeParameters->samplingFrequencyHz;
    const float centralFrequencyHz = probeParameters->centralFrequencyHz;
    const float lensCorrection = probeParameters->lensCorrection;
    const float elementSpacingInMillimeters = probeParameters->elementSpacingInMillimeters;
    const int angleCount = probeParameters->angleCount;
    const int samplesPerChannel = probeParameters->samplesPerChannel;
    const int channelCount = probeParameters->channelCount;
    
    const float speedOfSoundInMillimetersPerSecond = processingParameters->speedOfSoundInMillimetersPerSecond;
    const float fNumber = processingParameters->fNumber;
    const float imageStartXInMillimeters = processingParameters->imageStartXInMillimeters;
    const float imageStartZInMillimeters = processingParameters->imageStartZInMillimeters;
    const float lambda = speedOfSoundInMillimetersPerSecond / samplingFrequencyHz;
    const float pixelSpacingXInMillimeters = lambda / 2.f;
    const float pixelSpacingZInMillimeters = lambda / 2.f;
    
    uint imageSizeInPixelsWidth = outputTexture.get_width();
    //    int imageSizeInPixelsHeight = imageSizeInPixels.y;
    
    uint x = threadIdentifier % imageSizeInPixelsWidth;
    uint y = threadIdentifier / imageSizeInPixelsWidth;
    
    float probeWidthInMillimeters = float(channelCount) * elementSpacingInMillimeters;
    float probeStartXInMillimeters = -1.f * (probeWidthInMillimeters / 2.f);
    float pixelPositionXInMillimeters = float(x) * pixelSpacingXInMillimeters + imageStartXInMillimeters;
    float pixelPositionZInMillimeters = float(y) * pixelSpacingZInMillimeters + imageStartZInMillimeters;
    
    int samplesPerAngle = channelCount * samplesPerChannel;

    float2 anglesSum(0.f, 0.f);
    for (int angleNumber = 0; angleNumber < angleCount; angleNumber++) {
        float planeWaveAngleInRadians = anglesInRadians[angleNumber];
        float tauSend = pixelPositionXInMillimeters * sin(planeWaveAngleInRadians) + pixelPositionZInMillimeters * cos(planeWaveAngleInRadians);
        
        int angleChannelDataOffset = angleNumber * samplesPerAngle;
        
        float2 channelsSum(0.f, 0.f);
        for (int channelNumber = 0; channelNumber < channelCount; channelNumber++) {
            float2 channelValue(0.f, 0.f);
            float elementPositionXInMillimeters = float(channelNumber) * elementSpacingInMillimeters + probeStartXInMillimeters;
            float distanceX = abs(pixelPositionXInMillimeters - elementPositionXInMillimeters);
            float receiveAperture = pixelPositionZInMillimeters / fNumber;
            float distance = abs(distanceX);
            if (distance <= receiveAperture) {
                float arrayWidthInMillimeters = elementSpacingInMillimeters * channelCount;
                float angleToOriginOffset = abs((arrayWidthInMillimeters / 2.f) * sin(planeWaveAngleInRadians)) / speedOfSoundInMillimetersPerSecond;
                
                // tau = (z + sqrt(z^2 + (x - x_1)))/c
                float tauReceive = sqrt(pow(pixelPositionZInMillimeters, 2) + pow(distanceX, 2));
                float tau = (tauSend + tauReceive) / speedOfSoundInMillimetersPerSecond;
                float delay = samplingFrequencyHz * (tau + angleToOriginOffset) + lensCorrection;
                int lowerDelay = int(floor(delay));
                if (lowerDelay > samplesPerChannel) {
                    lowerDelay = 0;
                }
                
                int lowerSampleIndex = angleChannelDataOffset + (channelNumber * samplesPerChannel + lowerDelay);
                float2 lowerSample = float2(IQComplexSampleData[lowerSampleIndex]);
                float2 upperSample = float2(IQComplexSampleData[lowerSampleIndex + 1]);
                
                float alpha = ceil(delay) - delay;
                float2 lowerWeighted = multiplyC(lowerSample, float2(alpha, 0.f));
                float2 upperWeighted = multiplyC(upperSample, float2(1.f - alpha, 0.f));
                float2 IQData = addC(lowerWeighted, upperWeighted);
                
                float frequencyShiftedDelay = 2 * M_PI * centralFrequencyHz * delay / samplingFrequencyHz;
                float2 IQFrequencyShift = conjugateC(float2(cos(frequencyShiftedDelay), sin(frequencyShiftedDelay)));
                
                channelValue = multiplyC(IQFrequencyShift, IQData);
            }
            
            channelsSum = addC(channelsSum, channelValue);
        }
        
        anglesSum = addC(anglesSum, channelsSum);
    }
    float2 anglesCountC(angleCount, 0);
    float2 scaledSum = divideC(anglesSum, anglesCountC);
    
    float epsilon = 0.01f;
    float maximumValue = processingParameters->maximumValue;
    float dynamicRange = processingParameters->dynamicRange;
    float absoluteValue = absC(scaledSum) + epsilon;
    float decibelValue = decibel(absoluteValue);
    float shiftedDecibelValue = decibelValue - maximumValue;
    if (shiftedDecibelValue < -dynamicRange) {
        shiftedDecibelValue = -dynamicRange;
    }
    uint grayscaleValue = uint((255.f / dynamicRange) * (shiftedDecibelValue + dynamicRange));
    outputTexture.write(grayscaleValue, uint2(x, y));
}

inline float2 addC(float2 lhs, float2 rhs)
{
    return { lhs.x + rhs.x, lhs.y + rhs.y };
}
inline float2 subtractC(float2 lhs, float2 rhs)
{
    return { lhs.x - rhs.x, lhs.y - rhs.y };
}
inline float2 multiplyC(float2 lhs, float2 rhs)
{
    return { lhs.x * rhs.x - lhs.y * rhs.y, lhs.x * rhs.y + rhs.x * lhs.y };
}
inline float2 divideC(float2 lhs, float2 rhs)
{
    float2 result;
    result.x = (lhs.x * rhs.x + lhs.y * rhs.y) / (rhs.x * rhs.x + rhs.y * rhs.y);
    result.y = (lhs.y * rhs.x - lhs.x * rhs.y) / (rhs.x * rhs.x + rhs.y * rhs.y);
    return result;
}
inline float2 conjugateC(float2 lhs)
{
    return float2(lhs.x, -lhs.y);
}
inline float absC(float2 lhs)
{
    return sqrt(lhs.x * lhs.x + lhs.y * lhs.y);
}
inline float decibel(float value)
{
    return 20.f * log10(value);
}


