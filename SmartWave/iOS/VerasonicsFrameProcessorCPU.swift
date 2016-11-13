import Foundation
import Accelerate



public class VerasonicsFrameProcessorCPU: VerasonicsFrameProcessorBase
{
    private var queue: dispatch_queue_t!
    private let queueName = "no.uio.Beamformer"

   

    // MARK: Object lifecycle

    override init()
    {
        super.init()

        self.queue = dispatch_queue_create(queueName, DISPATCH_QUEUE_CONCURRENT)
    }

    // MARK:

    public func complexVectorFromChannelData(channelData: ChannelData?) -> [ComplexNumber]?
    {
        /* Interpolate the image*/
        var imageVector: [ComplexNumber]?
        if channelData != nil {
            var complexVectors = [ComplexNumber] ()
            dispatch_apply(self.numberOfActiveTransducerElements, self.queue, {
                (channelIdentifier: Int) -> Void in
                let startIndex = channelIdentifier * self.numberOfPixels
                let endIndex = startIndex + self.numberOfPixels
                let complexVector = self.complexVectorFromChannelDatum(channelData!, startIndex: startIndex, endIndex: endIndex)
                objc_sync_enter(self)
                complexVectors.appendContentsOf(complexVector)
                objc_sync_exit(self)
            })


            imageVector = self.imageVectorFromComplexVector(complexVectors)
        }

        return imageVector
    }

    func complexVectorFromChannelDatum(channelDatum: ChannelData, startIndex: Int, endIndex: Int) -> [ComplexNumber]
    {
        let numberOfElements = endIndex - startIndex

        var complexVector = [ComplexNumber](count: numberOfElements, repeatedValue: ComplexNumber(real: 0, imaginary: 0))
        var i = 0
        for index in startIndex ..< endIndex {
            let xnIndex = self.x_ns![index]
            let xn1Index = xnIndex + 1

            let sampleCount = channelDatum.complexSamples.count
            if xnIndex != -1  && xn1Index < sampleCount {
                var lower = channelDatum.complexSamples[xnIndex]
                let alpha = self.alphas![index]
                lower *= alpha

                var upper = channelDatum.complexSamples[xn1Index]
                let oneMinusAlpha = 1 - alpha
                upper *= oneMinusAlpha

                let partA = self.partAs![index]
                let partB = lower + upper
                let result = partA * partB

                complexVector[i].real = result.real
                complexVector[i].imaginary = result.imaginary
            }

            i += 1
        }

        return complexVector
    }
    

    func imageVectorFromComplexVector(complexVector: [ComplexNumber]) -> [ComplexNumber]
    {
        var imageVectorReals = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var imageVectorImaginaries = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var imageVectorWrapper = DSPSplitComplex(realp: &imageVectorReals, imagp: &imageVectorImaginaries)

        let splitVector = ComplexVector(complexNumbers: complexVector)
        let splitVectorReals = splitVector.reals!
        let splitVectorImaginaries = splitVector.imaginaries!
        dispatch_apply(self.numberOfActiveTransducerElements, self.queue) {
            (channelIdentifier: Int) -> Void in
            let startIndex = channelIdentifier * self.numberOfPixels
            let endIndex = startIndex + self.numberOfPixels
            var splitVectorRealsSlice = Array(splitVectorReals[startIndex ..< endIndex])
            var splitVectorImaginariesSlice = Array(splitVectorImaginaries[startIndex ..< endIndex])
            var splitVectorWrapper = DSPSplitComplex(realp: &splitVectorRealsSlice, imagp: &splitVectorImaginariesSlice)
            objc_sync_enter(self)
            vDSP_zvadd(&splitVectorWrapper, 1, &imageVectorWrapper, 1, &imageVectorWrapper, 1, UInt(self.numberOfPixels))
            objc_sync_exit(self)
        }

        return ComplexVector(reals: imageVectorReals, imaginaries: imageVectorImaginaries).complexNumbers!
    }

    public func imageAmplitudesFromComplexImageVector(complexImageVector: [ComplexNumber]?,
        numberOfAmplitudes: Int) -> [UInt8]?
    {
        var imageIntensities: [UInt8]?
        if complexImageVector != nil {
            let imageAmplitudes = complexImageVector!.map({
                (complexNumber: ComplexNumber) -> Float in
                return abs(complexNumber)
            })

            // convert complex value to double
            let minimumValue = imageAmplitudes.minElement()!
            let maximumValue = imageAmplitudes.maxElement()!
            var scaledImageAmplitudes = imageAmplitudes.map({
                (imageAmplitude: Float) -> Float in
                return (((imageAmplitude - minimumValue) / (maximumValue - minimumValue)) * 255.0) + 1.0
            })

            // convert float to decibeL
            var decibelValues = [Float](count: numberOfAmplitudes, repeatedValue: 0)
            var one: Float = 1;
            vDSP_vdbcon(&scaledImageAmplitudes, 1, &one, &decibelValues, 1, UInt(numberOfAmplitudes), 1)

            let decibelMinimumValues = decibelValues.minElement()!
            let decibelMaximumValues = decibelValues.maxElement()!
            var scaledDecibelValues = decibelValues.map({
                (decibelValue: Float) -> Float in
                return ((decibelValue - decibelMinimumValues) / (decibelMaximumValues - decibelMinimumValues)) * 255.0
            })

            imageIntensities = [UInt8](count: numberOfAmplitudes, repeatedValue: 0)
            vDSP_vfixu8(&scaledDecibelValues, 1, &imageIntensities!, 1, UInt(numberOfAmplitudes))
        }
        return imageIntensities
    }
}