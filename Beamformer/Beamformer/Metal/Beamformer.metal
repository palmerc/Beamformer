#include <metal_stdlib>
using namespace metal;



kernel void echo(const device uchar *input [[ buffer(0) ]],
                 device uchar *output [[ buffer(1) ]],
                 uint id [[thread_position_in_grid]])
{
    output[id] = input[id];
}

//public func complexImageVectorWithIQData(elementIQData: [ChannelData]?, width: Int, height: Int) -> ChannelData?
//{
//    /* Interpolate the image*/
//    var complexImageVector: ChannelData?
//    if elementIQData != nil {
//        let numberOfElements = elementIQData!.count
//        let numberOfPixels = width * height
//
//        complexImageVector = ChannelData(channelIdentifier: 0, numberOfSamples: numberOfPixels)
//        var interpolatedImageWrapper = DSPDoubleSplitComplex(realp: &complexImageVector!.real, imagp: &complexImageVector!.imaginary)
//        for elementIdentifier in 0 ..< numberOfElements {
//            var aComplexImageVector = complexImageVectorForElement(elementIdentifier,
//                                                                   elementDelayDatum: self.elementDelayData![elementIdentifier],
//                                                                   elementIQDatum: elementIQData![elementIdentifier])
//            var complexWrapper = DSPDoubleSplitComplex(realp: &aComplexImageVector.real, imagp: &aComplexImageVector.imaginary)
//            vDSP_zvaddD(&interpolatedImageWrapper, 1, &complexWrapper, 1, &interpolatedImageWrapper, 1, UInt(numberOfPixels))
//        }
//    }
//
//        return complexImageVector
//        }
//
//        public func complexImageVectorForElement(elementIdentifier: Int,
//                                                 elementDelayDatum: ElementDelayData,
//                                                 var elementIQDatum: ChannelData) -> ChannelData
//    {
//        let delays = elementDelayDatum.delays
//        let numberOfDelays = delays.count
//        let x_ns = delays.map({
//            (delay: Double) -> Double in
//            return Double(floor(delay))
//        })
//        var x_n1s = delays.map({
//            (delay: Double) -> Double in
//            return Double(ceil(delay))
//        })
//
//        var alphas = [Double](count: numberOfDelays, repeatedValue: 0)
//        vDSP_vsubD(delays, 1, &x_n1s, 1, &alphas, 1, UInt(numberOfDelays))
//
//        var ones = [Double](count: numberOfDelays, repeatedValue: 1)
//        var oneMinusAlphas = [Double](count: numberOfDelays, repeatedValue: 0)
//        vDSP_vsubD(&alphas, 1, &ones, 1, &oneMinusAlphas, 1, UInt(numberOfDelays))
//
//        var lowerReals = x_ns.enumerate().map {
//            (index: Int, x_n: Double) -> Double in
//            let index = Int(x_n)
//            if (index < 400) {
//                return elementIQDatum.real[index]
//            } else {
//                return 0
//            }
//        }
//        var lowerImaginaries = x_ns.enumerate().map {
//            (index: Int, x_n: Double) -> Double in
//            let index = Int(x_n)
//            if (index < 400) {
//                return elementIQDatum.imaginary[index]
//            } else {
//                return 0
//            }
//        }
//        var lowers = DSPDoubleSplitComplex(realp: &lowerReals, imagp: &lowerImaginaries)
//        vDSP_zrvmulD(&lowers, 1, &alphas, 1, &lowers, 1, UInt(numberOfDelays))
//
//        var upperReals = x_n1s.enumerate().map {
//            (index: Int, x_n1: Double) -> Double in
//            let index = Int(x_n1)
//            if (index < 400) {
//                return elementIQDatum.real[index]
//            } else {
//                return 0
//            }
//        }
//        var upperImaginaries = x_n1s.enumerate().map {
//            (index: Int, x_n1: Double) -> Double in
//            let index = Int(x_n1)
//            if (index < 400) {
//                return elementIQDatum.imaginary[index]
//            } else {
//                return 0
//            }
//        }
//        var uppers = DSPDoubleSplitComplex(realp: &upperReals, imagp: &upperImaginaries)
//        vDSP_zrvmulD(&uppers, 1, &oneMinusAlphas, 1, &uppers, 1, UInt(numberOfDelays))
//
//        var partBData = ChannelData(channelIdentifier: elementIQDatum.channelIdentifier, numberOfSamples: numberOfDelays)
//        var partBs = DSPDoubleSplitComplex(realp: &partBData.real, imagp: &partBData.imaginary)
//        vDSP_zvaddD(&lowers, 1, &uppers, 1, &partBs, 1, UInt(numberOfDelays))
//
//        let elementDelays = delays.map({
//            (delay: Double) -> Double in
//            return 2 * M_PI * self.centralFrequency * delay / self.samplingFrequencyHertz
//        })
//
//        var partARealConjugates = elementDelays.map({ (delay: Double) -> Double in
//            let r = Foundation.exp(0.0)
//            return r * cos(delay)
//        })
//
//        var partAImaginaryConjugates = elementDelays.map({ (delay: Double) -> Double in
//            let r = Foundation.exp(0.0)
//            return -1.0 * r * sin(delay)
//        })
//        var partAs = DSPDoubleSplitComplex(realp: &partARealConjugates, imagp: &partAImaginaryConjugates)
//
//        var complexImageVector = ChannelData(channelIdentifier: elementIQDatum.channelIdentifier, numberOfSamples: numberOfDelays)
//        var complexImageWrapper = DSPDoubleSplitComplex(realp: &complexImageVector.real, imagp: &complexImageVector.imaginary)
//        vDSP_zvmulD(&partAs, 1, &partBs, 1, &complexImageWrapper, 1, UInt(numberOfDelays), 1)
//
//        return complexImageVector
//    }
//
//        public func imageAmplitudesFromComplexImageVector(complexImageVector: ChannelData?, width: Int, height: Int) -> [UInt8]?
//    {
//        var imageIntensities: [UInt8]?
//        if var imageVector = complexImageVector {
//            var complexImageWrapper = DSPDoubleSplitComplex(realp: &imageVector.real, imagp: &imageVector.imaginary)
//
//            // convert complex value to double
//            let numberOfAmplitudes = width * height
//            var imageAmplitudes = [Double](count: numberOfAmplitudes, repeatedValue: 0)
//            vDSP_zvabsD(&complexImageWrapper, 1, &imageAmplitudes, 1, UInt(numberOfAmplitudes))
//
//            let minimumValue = imageAmplitudes.minElement()!
//            let maximumValue = imageAmplitudes.maxElement()!
//            var scaledImageAmplitudes = imageAmplitudes.map({
//                (imageAmplitude: Double) -> Double in
//                return (((imageAmplitude - minimumValue) / (maximumValue - minimumValue)) * 255.0) + 1.0
//            })
//
//            var decibelValues = [Double](count: numberOfAmplitudes, repeatedValue: 0)
//            var one: Double = 1;
//            vDSP_vdbconD(&scaledImageAmplitudes, 1, &one, &decibelValues, 1, UInt(numberOfAmplitudes), 1)
//
//            let decibelMinimumValues = decibelValues.minElement()!
//            let decibelMaximumValues = decibelValues.maxElement()!
//            var scaledDecibelValues = decibelValues.map({
//                (decibelValue: Double) -> Double in
//                return ((decibelValue - decibelMinimumValues) / (decibelMaximumValues - decibelMinimumValues)) * 255.0
//            })
//            
//            // convert double to decibeL
//            imageIntensities = [UInt8](count: numberOfAmplitudes, repeatedValue: 0)
//            vDSP_vfixu8D(&scaledDecibelValues, 1, &imageIntensities!, 1, UInt(numberOfAmplitudes))
//        }
//        return imageIntensities
//    }