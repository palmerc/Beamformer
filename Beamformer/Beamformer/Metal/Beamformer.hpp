#ifndef Beamformer_hpp
#define Beamformer_hpp

#include <vector>

#include "ComplexNumbers.hpp"

std::vector<ComplexF> complexImageVectorWithComplexChannelVector(std::vector<int> x_ns,
                                                                 std::vector<int> x_n1s,
                                                                 std::vector<ComplexF> alphas,
                                                                 std::vector<ComplexF> oneMinusAlphas,
                                                                 std::vector<ComplexF> partAs,
                                                                 std::vector<ComplexF> complexChannelVector);

#endif
