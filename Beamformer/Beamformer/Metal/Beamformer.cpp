#include "Beamformer.hpp"

#include "ComplexNumbers.hpp"

#include <vector>



std::vector<ComplexF> complexImageVectorWithComplexChannelVector(std::vector<int> x_ns,
                                                                 std::vector<int> x_n1s,
                                                                 std::vector<ComplexF> alphas,
                                                                 std::vector<ComplexF> oneMinusAlphas,
                                                                 std::vector<ComplexF> partAs,
                                                                 std::vector<ComplexF> complexChannelVector)
{
    unsigned long numberOfSamplesPerChannel = complexChannelVector.size();

    std::vector<ComplexF> lowers;
    std::vector<ComplexF> uppers;
    for (int i = 0; i < x_ns.size(); i++) {
        ComplexF lower = ComplexF(0.f, 0.f);
        int x_n = x_ns[i];
        if (x_n < numberOfSamplesPerChannel) {
            lower = complexChannelVector[x_n];
        }
        lowers[i] = lower;

        ComplexF upper = ComplexF(0.f, 0.f);
        int x_n1 = x_n1s[i];
        if (x_n1 < numberOfSamplesPerChannel) {
            upper = complexChannelVector[x_n1];
        }
        uppers[i] = upper;
    }

    std::vector<ComplexF> partBs;
    for (int i = 0; i < numberOfSamplesPerChannel; i++) {
        ComplexF lower = multiply(lowers[i], alphas[i]);
        ComplexF upper = multiply(uppers[i], oneMinusAlphas[i]);
        partBs[i] = add(lower, upper);
    }

    std::vector<ComplexF> complexImageVector;
    for (int i = 0; i < numberOfSamplesPerChannel; i++) {
        complexImageVector[i] = multiply(partAs[i], partBs[i]);
    }

    return complexImageVector;
}