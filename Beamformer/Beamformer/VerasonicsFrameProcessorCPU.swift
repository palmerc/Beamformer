import Foundation
import Accelerate



public class VerasonicsFrameProcessorCPU: VerasonicsFrameProcessorBase
{
    private var queue: dispatch_queue_t!
    private let queueName = "no.uio.Beamformer"

    var x_ns: [Float]? = nil
    var x_n1s: [Float]? = nil
    var alphas: [Float]? = nil
    var oneMinusAlphas: [Float]? = nil
    var partAs: [ComplexNumber]? = nil

    private var _calculatedChannelDelays: [Float]? = nil
    var calculatedChannelDelays: [Float]? {
        get {            
            return self._calculatedChannelDelays
        }
        set {
            self._calculatedChannelDelays = newValue
            let (x_ns, x_n1s, alphas, oneMinusAlphas, partAs) = self.processCalculatedDelays(newValue!, centralFrequency: self.centralFrequency, samplingFrequencyHz: self.samplingFrequencyHz, numberOfElements: self.numberOfActiveTransducerElements)
            self.x_ns = x_ns
            self.x_n1s = x_n1s
            self.alphas = alphas
            self.oneMinusAlphas = oneMinusAlphas
            self.partAs = partAs
        }
    }

    private var _elementPositions: [Float]? = nil
    var elementPositions: [Float]? {
        get {
            return self._elementPositions
        }
        set {
            self._elementPositions = newValue
            self.calculatedChannelDelays = calculatedDelaysWithElementPositions(newValue)
        }
    }


    // MARK: Object lifecycle

    public init(withElementPositions positions: [Float])
    {
        super.init()
        
        self.queue = dispatch_queue_create(queueName, DISPATCH_QUEUE_CONCURRENT)
        self.elementPositions = positions
    }

    // MARK:

    public func complexVectorFromChannelData(channelData: ChannelData?) -> [ComplexNumber]?
    {
        /* Interpolate the image*/
        var imageVector: [ComplexNumber]?
        if channelData != nil {
            let startIndex = 0
            let endIndex = self.numberOfActiveTransducerElements * self.numberOfPixels
            let complexVector = self.complexVectorFromChannelDatum(channelData!, startIndex: startIndex, endIndex: endIndex)

            imageVector = self.imageVectorFromComplexVector(complexVector)
        }

        return imageVector
    }

    func complexVectorFromChannelDatum(channelDatum: ChannelData, startIndex: Int, endIndex: Int) -> [ComplexNumber]
    {
        let numberOfElements = endIndex - startIndex

        var complexVector = [ComplexNumber](count: numberOfElements, repeatedValue: ComplexNumber(real: 0, imaginary: 0))
        var i = 0
        for index in startIndex ..< endIndex {
            var lower: ComplexNumber
            let xn = self.x_ns![index]
            let xnIndex = Int(xn)
            if xnIndex < channelDatum.samplesPerChannel {
                lower = channelDatum.complexSamples[xnIndex]
            } else {
                lower = ComplexNumber(real: 0, imaginary: 0)
            }
            lower *= self.alphas![index]

            var upper: ComplexNumber
            let xn1 = self.x_n1s![index]
            let xn1Index = Int(xn1)
            if xn1Index < channelDatum.samplesPerChannel {
                upper = channelDatum.complexSamples[xn1Index]
            } else {
                upper = ComplexNumber(real: 0, imaginary: 0)
            }
            upper *= self.oneMinusAlphas![index]

            let partA = self.partAs![index]
            let partB = lower + upper
            let result = partA * partB

            complexVector[i].real = result.real
            complexVector[i].imaginary = result.imaginary
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
        for channelIndex in 0 ..< self.numberOfActiveTransducerElements {
            let startIndex = channelIndex * self.numberOfPixels
            let endIndex = startIndex + self.numberOfPixels
            var splitVectorRealsSlice = Array(splitVectorReals[startIndex ..< endIndex])
            var splitVectorImaginariesSlice = Array(splitVectorImaginaries[startIndex ..< endIndex])
            var splitVectorWrapper = DSPSplitComplex(realp: &splitVectorRealsSlice, imagp: &splitVectorImaginariesSlice)
            vDSP_zvadd(&splitVectorWrapper, 1, &imageVectorWrapper, 1, &imageVectorWrapper, 1, UInt(self.numberOfPixels))
        }

        return ComplexVector(reals: imageVectorReals, imaginaries: imageVectorImaginaries).complexNumbers!
    }

    func calculatedDelaysWithElementPositions(elementPositions: [Float]?) -> [Float]?
    {
        var calculatedDelays: [Float]?
        if (elementPositions != nil) {
            let angle: Float = 0
            var xs = [Float](count: self.imageXPixelCount, repeatedValue: 0)
            for i in 0..<self.imageXPixelCount {
                xs[i] = self.imageXStartInMM + Float(i) * self.imageXPixelSpacing
            }
            var zs = [Float](count: self.imageZPixelCount, repeatedValue: 0)
            for i in 0..<self.imageZPixelCount {
                zs[i] = self.imageZStartInMM + Float(i) * self.imageZPixelSpacing
            }

            var xIndices = [Int](count: self.numberOfPixels, repeatedValue: 0)
            var zIndices = [Int](count: self.numberOfPixels, repeatedValue: 0)
            var delayIndices = [Int](count: self.numberOfPixels, repeatedValue: 0)
            var zSquareds = [Float](count: self.numberOfPixels, repeatedValue: 0)
            var unrolledXs = [Float](count: self.numberOfPixels, repeatedValue: 0)
            var xSineAlphas = [Float](count: self.numberOfPixels, repeatedValue: 0)
            var zCosineAlphas = [Float](count: self.numberOfPixels, repeatedValue: 0)
            for index in 0 ..< self.numberOfPixels {
                let xIndex = index % self.imageXPixelCount
                let zIndex = index / self.imageXPixelCount
                xIndices[index] = xIndex
                zIndices[index] = zIndex
                unrolledXs[index] = xs[xIndex]
                delayIndices[index] = xIndex * self.imageZPixelCount + zIndex
                zSquareds[index] = pow(Float(zs[zIndex]), 2)
                xSineAlphas[index] = Float(xs[xIndex]) * sin(angle)
                zCosineAlphas[index] = Float(zs[zIndex]) * cos(angle)
            }
            let tauEchos = zCosineAlphas.enumerate().map({
                (index: Int, zCosineAlpha: Float) -> Float in
                return (zCosineAlpha + xSineAlphas[index]) / self.speedOfUltrasound
            })

            let numberOfDelays = self.numberOfActiveTransducerElements * self.numberOfPixels
            calculatedDelays = [Float](count: numberOfDelays, repeatedValue: 0)
            for channelIdentifier in 0 ..< self.numberOfActiveTransducerElements {
                let channelDelays = elementPositions![channelIdentifier]
                for index in 0 ..< self.numberOfPixels {
                    let xDifferenceSquared = pow(unrolledXs[index] - channelDelays, 2)
                    let tauReceive = sqrt(zSquareds[index] + xDifferenceSquared) / self.speedOfUltrasound

                    let delay = (tauEchos[index] + tauReceive) * self.samplingFrequencyHz + self.lensCorrection

                    let lookupIndex = delayIndices[index]
                    let delayIndex = channelIdentifier * self.numberOfPixels + lookupIndex
                    calculatedDelays![delayIndex] = delay
                }
            }
        }

        return calculatedDelays
    }

    func processCalculatedDelays(calculatedDelays: [Float],
        centralFrequency: Float,
        samplingFrequencyHz: Float,
        numberOfElements: Int)
        -> (x_ns: [Float], x_n1s: [Float], alphas: [Float], oneMinusAlphas: [Float], partAs: [ComplexNumber])
    {
        let x_ns = calculatedDelays.map({
            (channelDelay: Float) -> Float in
            return Float(floor(channelDelay))
        })

        let x_n1s = calculatedDelays.map({
            (channelDelay: Float) -> Float in
            return Float(ceil(channelDelay))
        })

        var alphas = [Float](count: calculatedDelays.count, repeatedValue: 0)
        vDSP_vsub(calculatedDelays, 1, x_n1s, 1, &alphas, 1, UInt(calculatedDelays.count))

        let ones = [Float](count: calculatedDelays.count, repeatedValue: 1)
        var oneMinusAlphas = [Float](count: calculatedDelays.count, repeatedValue: 0)
        vDSP_vsub(alphas, 1, ones, 1, &oneMinusAlphas, 1, UInt(calculatedDelays.count))

        let shiftedDelays = calculatedDelays.map({
            (channelDelay: Float) -> Float in
            return 2 * Float(M_PI) * centralFrequency * channelDelay / samplingFrequencyHz
        })

        let realConjugates = shiftedDelays.map({
            (calculatedDelay: Float) -> Float in
            let r = Foundation.exp(Float(0))
            return r * cos(calculatedDelay)
        })

        let imaginaryConjugates = shiftedDelays.map({
            (calculatedDelay: Float) -> Float in
            let r = Foundation.exp(Float(0))
            return -1.0 * r * sin(calculatedDelay)
        })

        let partAs = ComplexVector(reals: realConjugates, imaginaries: imaginaryConjugates).complexNumbers!

        return (x_ns, x_n1s, alphas, oneMinusAlphas, partAs)
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

            var decibelValues = [Float](count: numberOfAmplitudes, repeatedValue: 0)
            var one: Float = 1;
            vDSP_vdbcon(&scaledImageAmplitudes, 1, &one, &decibelValues, 1, UInt(numberOfAmplitudes), 1)

            let decibelMinimumValues = decibelValues.minElement()!
            let decibelMaximumValues = decibelValues.maxElement()!
            var scaledDecibelValues = decibelValues.map({
                (decibelValue: Float) -> Float in
                return ((decibelValue - decibelMinimumValues) / (decibelMaximumValues - decibelMinimumValues)) * 255.0
            })

            // convert double to decibeL
            imageIntensities = [UInt8](count: numberOfAmplitudes, repeatedValue: 0)
            vDSP_vfixu8(&scaledDecibelValues, 1, &imageIntensities!, 1, UInt(numberOfAmplitudes))
        }
        return imageIntensities
    }
}