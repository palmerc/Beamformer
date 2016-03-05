#ifndef Beamformer_hpp
#define Beamformer_hpp

#include "BeamformerParameters.h"
#include "ComplexNumbers.hpp"


#ifdef __cplusplus
extern "C" {
#endif
    void processChannelData(const BeamformerParameters beamformerParameters,
                            const ComplexNumberF *inputChannelData,
                            const ComplexNumberF *partAs,
                            const float *alphas,
                            const long *x_ns,
                            ComplexNumberF *outputChannelData,
                            const unsigned long threadgroupIdentifier,
                            const unsigned long threadgroups,
                            const unsigned long threadIdentifier,
                            const unsigned long threadsPerThreadgroup);
#ifdef __cplusplus
}
#endif

#endif
