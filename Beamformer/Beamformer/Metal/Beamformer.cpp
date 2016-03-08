#include "Beamformer.hpp"
#include <pthread.h>



void processChannelData(const BeamformerParametersF beamformerParameters,
                        const ComplexNumberF *inputChannelData,
                        const ComplexNumberF *partAs,
                        const float *alphas,
                        const long *x_ns,
                        ComplexNumberF *outputChannelData,
                        const unsigned long threadgroupIdentifier,
                        const unsigned long threadgroups,
                        const unsigned long threadIdentifier,
                        const unsigned long threadsPerThreadgroup)
{
    long channelCount = beamformerParameters.channelCount; // 128
    long samplesPerChannel = beamformerParameters.samplesPerChannel; // 400
    long xnCutoff = channelCount * samplesPerChannel;

    long pixelCount = beamformerParameters.pixelCount;
    long totalSamples = channelCount * pixelCount;

    long samplesPerThreadgroup = totalSamples / threadgroups;
    long samplesPerThread = samplesPerThreadgroup / threadsPerThreadgroup;

    long threadOffset = threadgroupIdentifier * threadsPerThreadgroup + threadIdentifier;
    long startIndex = threadOffset * samplesPerThread;
    long endIndex = startIndex + samplesPerThread;
    for (long index = startIndex; index < endIndex; index++) {
        long xnIndex = x_ns[index];
        long xn1Index = xnIndex + 1;

        if (xnIndex != -1 && xn1Index < xnCutoff) {
            ComplexNumberF partA = partAs[index];
            ComplexNumberF lower = inputChannelData[xnIndex];
            ComplexNumberF upper = inputChannelData[xn1Index];

            float alpha = alphas[index];
            ComplexNumberF complexAlpha = {.real = alpha, .imaginary = 0.0};
            lower = multiply(lower, complexAlpha);

            float oneMinusAlpha = 1.0 - alpha;
            ComplexNumberF complexOneMinusAlpha = {.real = oneMinusAlpha, .imaginary = 0.0};
            upper = multiply(upper, complexOneMinusAlpha);

            ComplexNumberF partB = add(lower, upper);
            ComplexNumberF result = multiply(partA, partB);

            outputChannelData[index].real = result.real;
            outputChannelData[index].imaginary = result.imaginary;
        }
    }
}
