#import "VerasonicsFrameMetalProcessor.h"

#include <vector>
#include <cmath>
#include <cstring>
#include "Beamformer.hpp"
#include "ComplexNumbers.hpp"



@implementation VerasonicsFrameMetalProcessor

- (NSArray<NSNumber *> *)processChannelData:(NSArray<NSNumber *> *)channelData withChannelDelays:(NSArray<NSNumber *> *)channelDelays
{
    unsigned long numberOfDelays = channelDelays.count;
    NSMutableArray * complexImageVectorReturned = [[NSMutableArray alloc] initWithCapacity:100];
    // channelData. value.floatValue
    //int speedOfUltrasound = 1540 * 1000;
    int samplingFrequencyHz = 7813000;
    int centralFrequency = 7813000;
    //double lensCorrection = 14.14423409;
    //int numberOfTransducerElements = 192;
    int numberOfActiveTransducerElements = 128;
    int delaysPerChannel = floor(1.0*numberOfDelays/numberOfActiveTransducerElements);
    size_t count = sizeof(float)*delaysPerChannel;
    void * complexImageVector = malloc(count);
    memset(complexImageVector, 0, count);
    float *floatPointer = (float *)complexImageVector;
    
    for (int elmt = 0; elmt < numberOfActiveTransducerElements; elmt++) {
        for (int sample = 0; sample < delaysPerChannel; sample++) {
            float channelDelay = [channelDelays[sample+elmt*delaysPerChannel] floatValue];
            int x_n = floorf(channelDelay);
            int x_n1 = ceilf(channelDelay);
            float alpha = x_n1 - channelDelay;
            
            if (x_n < 400 && x_n1 < 400){
                float phaseShiftPart = 2 * M_PI * centralFrequency * channelDelay / samplingFrequencyHz;
                float realPhaseShift = cosf(phaseShiftPart);
                float imagPhaseShift = -1.f*sinf(phaseShiftPart);
                float data1Real = (alpha)*[channelData[(x_n+elmt*400)*2] floatValue];
                float data1Imag = (alpha)*[channelData[(x_n+elmt*400)*2+1] floatValue];
                float data2Real = (1-alpha)*[channelData[(x_n1+elmt*400)*2] floatValue];
                float data2Imag = (1-alpha)*[channelData[(x_n1+elmt*400)*2+1] floatValue];
                float dataReal = data1Real+data2Real;
                float dataImag = data1Imag+data2Imag;
                
                //The real part( a   *   c )      -     (b        *     d)
                float R = realPhaseShift*dataReal - imagPhaseShift*dataImag;
                
                
                floatPointer[(sample)*2] = floatPointer[(sample)*2] + R;
                //The imaginary part ( a  * d )   +  (b  *  c)
                float I = realPhaseShift*dataImag+imagPhaseShift*dataReal;
                floatPointer[(sample)*2+1] = floatPointer[(sample)*2+1] + I;
            }
        }
    }
    
    for (int sample = 0; sample < delaysPerChannel; sample++) {
        [complexImageVectorReturned addObject:[NSNumber numberWithFloat:floatPointer[sample*2]]];
        [complexImageVectorReturned addObject:[NSNumber numberWithFloat:floatPointer[sample*2+1]]];
    }
    
    free(floatPointer);
    return complexImageVectorReturned;
}

@end
