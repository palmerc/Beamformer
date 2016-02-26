import Foundation
import Accelerate



public class VerasonicsFrameProcessorCPU: VerasonicsFrameProcessorBase
{
    private var queue: dispatch_queue_t!
    private let queueName = "no.uio.Beamformer"

    var x_ns: [[Float]]? = nil
    var x_n1s: [[Float]]? = nil
    var alphas: [[Float]]? = nil
    var oneMinusAlphas: [[Float]]? = nil
    var partAs: [ComplexVector]? = nil

    private var _calculatedChannelDelays: [ChannelDelay]? = nil
    var calculatedChannelDelays: [ChannelDelay]? {
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
            self.calculatedChannelDelays = calculatedDelayWithElementPositions(newValue)
        }
    }



    public init(withElementPositions positions: [Float])
    {
        super.init()
        
        self.queue = dispatch_queue_create(queueName, DISPATCH_QUEUE_CONCURRENT)
        self.elementPositions = positions
    }



    public func complexVectorFromChannelData(channelData: [ChannelData]?) -> ComplexVector?
    {
        /* Interpolate the image*/
        var complexVector: ComplexVector?
        if channelData != nil {
            let numberOfChannels = channelData!.count

            complexVector = ComplexVector(count: self.numberOfPixels, repeatedValue: 0)
            var complexImageVectorWrapper = DSPSplitComplex(realp: &complexVector!.reals!, imagp: &complexVector!.imaginaries!)

            dispatch_apply(numberOfChannels, self.queue, {
                (channelIdentifier: Int) -> Void in
                let channelDatum = channelData![channelIdentifier]
                var aComplexImageVector = self.complexVectorFromChannelDatum(channelDatum)
                var aComplexImageVectorWrapper = DSPSplitComplex(realp: &aComplexImageVector.reals!, imagp: &aComplexImageVector.imaginaries!)
                vDSP_zvadd(&aComplexImageVectorWrapper, 1, &complexImageVectorWrapper, 1, &complexImageVectorWrapper, 1, UInt(self.numberOfPixels))
            })
        }

        return complexVector
    }

    func complexVectorFromChannelDatum(channelDatum: ChannelData) -> ComplexVector
    {
        let channelIdentifier = channelDatum.channelIdentifier
        let complexChannelVector = channelDatum.complexVector
        let numberOfSamplesPerChannel = complexChannelVector.count
        let numberOfDelays = self.partAs![channelIdentifier].count

        var lowerReals = self.x_ns![channelIdentifier].enumerate().map {
            (index: Int, x_n: Float) -> Float in
            let index = Int(x_n)
            if (index < numberOfSamplesPerChannel) {
                return complexChannelVector.reals![index]
            } else {
                return 0
            }
        }
        var lowerImaginaries = self.x_ns![channelIdentifier].enumerate().map {
            (index: Int, x_n: Float) -> Float in
            let index = Int(x_n)
            if (index < numberOfSamplesPerChannel) {
                return complexChannelVector.imaginaries![index]
            } else {
                return 0
            }
        }
        var lowers = DSPSplitComplex(realp: &lowerReals, imagp: &lowerImaginaries)
        vDSP_zrvmul(&lowers, 1, self.alphas![channelIdentifier], 1, &lowers, 1, UInt(numberOfDelays))

        var upperReals = self.x_n1s![channelIdentifier].enumerate().map {
            (index: Int, x_n1: Float) -> Float in
            let index = Int(x_n1)
            if (index < numberOfSamplesPerChannel) {
                return complexChannelVector.reals![index]
            } else {
                return 0
            }
        }
        var upperImaginaries = self.x_n1s![channelIdentifier].enumerate().map {
            (index: Int, x_n1: Float) -> Float in
            let index = Int(x_n1)
            if (index < numberOfSamplesPerChannel) {
                return complexChannelVector.imaginaries![index]
            } else {
                return 0
            }
        }
        var uppers = DSPSplitComplex(realp: &upperReals, imagp: &upperImaginaries)
        vDSP_zrvmul(&uppers, 1, self.oneMinusAlphas![channelIdentifier], 1, &uppers, 1, UInt(numberOfDelays))

        var partBData = ComplexVector(count: numberOfDelays, repeatedValue: 0)
        var partBs = DSPSplitComplex(realp: &partBData.reals!, imagp: &partBData.imaginaries!)
        vDSP_zvadd(&lowers, 1, &uppers, 1, &partBs, 1, UInt(numberOfDelays))

        var partA = self.partAs![channelIdentifier]
        var partAWrapper = DSPSplitComplex(realp: &partA.reals!, imagp: &partA.imaginaries!)
        var complexVector = ComplexVector(count: numberOfDelays, repeatedValue: 0)
        var complexVectorWrapper = DSPSplitComplex(realp: &complexVector.reals!, imagp: &complexVector.imaginaries!)
        vDSP_zvmul(&partAWrapper, 1, &partBs, 1, &complexVectorWrapper, 1, UInt(numberOfDelays), 1)
        
        return complexVector
    }

    func calculatedDelayWithElementPositions(elementPositions: [Float]?) -> [ChannelDelay]?
    {
        var calculatedDelays: [ChannelDelay]?
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

            calculatedDelays = [ChannelDelay](count:self.numberOfActiveTransducerElements, repeatedValue: ChannelDelay(channelIdentifier: 0, numberOfDelays: self.numberOfPixels))
            for channelIdentifier in 0 ..< self.numberOfActiveTransducerElements {
                calculatedDelays![channelIdentifier].identifier = channelIdentifier

                let channelDelays = elementPositions![channelIdentifier]
                for index in 0 ..< self.numberOfPixels {
                    let xDifferenceSquared = pow(unrolledXs[index] - channelDelays, 2)
                    let tauReceive = sqrt(zSquareds[index] + xDifferenceSquared) / self.speedOfUltrasound

                    let delay = (tauEchos[index] + tauReceive) * self.samplingFrequencyHz + self.lensCorrection
                    
                    let delayIndex = delayIndices[index]
                    calculatedDelays![channelIdentifier].delays[delayIndex] = delay
                }
            }
        }

        return calculatedDelays
    }

    func processCalculatedDelays(calculatedDelays: [ChannelDelay],
        centralFrequency: Float,
        samplingFrequencyHz: Float,
        numberOfElements: Int)
        -> (x_ns: [[Float]], x_n1s: [[Float]], alphas: [[Float]], oneMinusAlphas: [[Float]], partAs: [ComplexVector])
    {
        var x_ns = [[Float]](count: numberOfElements, repeatedValue: [Float]())
        var x_n1s = [[Float]](count: numberOfElements, repeatedValue: [Float]())
        var alphas = [[Float]](count: numberOfElements, repeatedValue: [Float]())
        var oneMinusAlphas = [[Float]](count: numberOfElements, repeatedValue: [Float]())
        var partAs = [ComplexVector](count: numberOfElements, repeatedValue: ComplexVector())

        for channelIdentifier in 0 ..< numberOfElements {
            let channelDelays = calculatedDelays[channelIdentifier].delays
            let numberOfDelays = channelDelays.count

            let x_n = channelDelays.map({
                (channelDelay: Float) -> Float in
                return Float(floor(channelDelay))
            })
            x_ns[channelIdentifier] = x_n

            let x_n1 = channelDelays.map({
                (channelDelay: Float) -> Float in
                return Float(ceil(channelDelay))
            })
            x_n1s[channelIdentifier] = x_n1

            var alpha = [Float](count: numberOfDelays, repeatedValue: 0)
            vDSP_vsub(channelDelays, 1, x_n1, 1, &alpha, 1, UInt(numberOfDelays))
            alphas[channelIdentifier] = alpha

            let ones = [Float](count: numberOfDelays, repeatedValue: 1)
            var oneMinusAlpha = [Float](count: numberOfDelays, repeatedValue: 0)
            vDSP_vsub(alpha, 1, ones, 1, &oneMinusAlpha, 1, UInt(numberOfDelays))
            oneMinusAlphas[channelIdentifier] = oneMinusAlpha

            let calculatedDelay = channelDelays.map({
                (channelDelay: Float) -> Float in
                return 2 * Float(M_PI) * centralFrequency * channelDelay / samplingFrequencyHz
            })

            let realConjugates = calculatedDelay.map({
                (calculatedDelay: Float) -> Float in
                let r = Foundation.exp(Float(0))
                return r * cos(calculatedDelay)
            })

            let imaginaryConjugates = calculatedDelay.map({
                (calculatedDelay: Float) -> Float in
                let r = Foundation.exp(Float(0))
                return -1.0 * r * sin(calculatedDelay)
            })

            partAs[channelIdentifier] = ComplexVector(reals: realConjugates, imaginaries: imaginaryConjugates)
        }

        return (x_ns, x_n1s, alphas, oneMinusAlphas, partAs)
    }

    public func imageAmplitudesFromComplexImageVector(complexImageVector: ComplexVector?,
        numberOfAmplitudes: Int) -> [UInt8]?
    {
        var imageIntensities: [UInt8]?
        if complexImageVector != nil {
            let imageVector = complexImageVector!
            var reals = imageVector.reals!
            var imaginaries = imageVector.imaginaries!
            var complexImageWrapper = DSPSplitComplex(realp: &reals, imagp: &imaginaries)

            // convert complex value to double
            var imageAmplitudes = [Float](count: numberOfAmplitudes, repeatedValue: 0)
            vDSP_zvabs(&complexImageWrapper, 1, &imageAmplitudes, 1, UInt(numberOfAmplitudes))

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