#include <metal_stdlib>
using namespace metal;


struct ChannelDataParameters {
    int numberOfChannelDataSamples;
    int numberOfPixels;
};

struct ComplexNumber {
    float real;
    float imaginary;
};

ComplexNumber add(ComplexNumber lhs, ComplexNumber rhs);
ComplexNumber subtract(ComplexNumber lhs, ComplexNumber rhs);
ComplexNumber multiply(ComplexNumber lhs, ComplexNumber rhs);



kernel void processChannelData(const device ChannelDataParameters *channelDataParameters [[ buffer(0) ]],
                               const device ComplexNumber *inputChannelData [[ buffer(1) ]],
                               const device ComplexNumber *partAs [[ buffer(2) ]],
                               const device ComplexNumber *alphas [[ buffer(3) ]],
                               const device int *x_ns [[ buffer(4) ]],
                               device ComplexNumber *outputChannelData [[ buffer(5) ]],
                               uint threadIdentifier [[thread_position_in_grid]])
{
    int startIndex = threadIdentifier * channelDataParameters->numberOfPixels;
    int endIndex = startIndex + channelDataParameters->numberOfPixels;

    for (int index = startIndex; index < endIndex; index++) {
        int xnIndex = x_ns[index];
        int xn1Index = xnIndex + 1;

        if (xnIndex != -1 && xn1Index < channelDataParameters->numberOfChannelDataSamples) {
            ComplexNumber partA = partAs[index];

            ComplexNumber alpha = alphas[index];
            ComplexNumber lower = inputChannelData[xnIndex];
            lower = multiply(lower, alpha);

            ComplexNumber upper = inputChannelData[xn1Index];
            ComplexNumber one = {.real = 1, .imaginary = 0};
            ComplexNumber oneMinusAlpha = subtract(one, alpha);
            upper = multiply(upper, oneMinusAlpha);

            ComplexNumber partB = add(lower, upper);
            ComplexNumber result = multiply(partA, partB);

            outputChannelData[index].real = result.real;
            outputChannelData[index].imaginary = result.imaginary;
        }
    }
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
