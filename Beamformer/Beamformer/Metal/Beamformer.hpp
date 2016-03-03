#ifndef Beamformer_hpp
#define Beamformer_hpp

#include "ComplexNumbers.hpp"


#ifdef __cplusplus
extern "C" {
#endif
    void processChannelData(const ComplexNumberF *inputChannelData,
                        const ComplexNumberF *partAs,
                        const float *alphas,
                        const long *x_ns,
                        ComplexNumberF *outputChannelData);
#ifdef __cplusplus
}
#endif

#endif
