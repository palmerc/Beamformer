#include "Beamformer.hpp"



void processChannelData(const ComplexNumberF *inputChannelData,
                        const ComplexNumberF *partAs,
                        const float *alphas,
                        const long *x_ns,
                        ComplexNumberF *outputChannelData)
{
    int numberOfPixels = 130806;
    int startIndex = 0;
    int endIndex = 128 * numberOfPixels;

    for (int index = startIndex; index < endIndex; index++) {
        long xnIndex = x_ns[index];
        long xn1Index = xnIndex + 1;

        if (xnIndex != -1 && xn1Index < 51200) {
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
