import Foundation
import UIKit
import CoreGraphics
import Accelerate



public class VerasonicsFrameProcessor: NSObject
{
    private let speedOfUltrasound: Double = 1540 * 1000
    private let samplingFrequencyHertz: Double = 7813000
    private let lensCorrection: Double = 14.14423409
    private let numberOfTransducerElements: Int = 192
    private let numberOfActiveTransducerElements: Int = 128
    private let imageZStartInMM: Double = 0.0
    private let imageZStopInMM: Double = 50.0

    static let defaultDelays: [Double] = [
        -12.70, -12.50, -12.30, -12.10, -11.90, -11.70,
        -11.50, -11.30, -11.10, -10.90, -10.70, -10.50,
        -10.30, -10.10,  -9.90,  -9.70,  -9.50,  -9.30,
         -9.10,  -8.90,  -8.70,  -8.50,  -8.30,  -8.10,
         -7.90,  -7.70,  -7.50,  -7.30,  -7.10,  -6.90,
         -6.70,  -6.50,  -6.30,  -6.10,  -5.90,  -5.70,
         -5.50,  -5.30,  -5.10,  -4.90,  -4.70,  -4.50,
         -4.30,  -4.10,  -3.90,  -3.70,  -3.50,  -3.30,
         -3.10,  -2.90,  -2.70,  -2.50,  -2.30,  -2.10,
         -1.90,  -1.70,  -1.50,  -1.30,  -1.10,  -0.90,
         -0.70,  -0.50,  -0.30,  -0.10,   0.10,   0.30,
          0.50,   0.70,   0.90,   1.10,   1.30,   1.50,
          1.70,   1.90,   2.10,   2.30,   2.50,   2.70,
          2.90,   3.10,   3.30,   3.50,   3.70,   3.90,
          4.10,   4.30,   4.50,   4.70,   4.90,   5.10,
          5.30,   5.50,   5.70,   5.90,   6.10,   6.30,
          6.50,   6.70,   6.90,   7.10,   7.30,   7.50,
          7.70,   7.90,   8.10,   8.30,   8.50,   8.70,
          8.90,   9.10,   9.30,   9.50,   9.70,   9.90,
         10.10,  10.30,  10.50,  10.70,  10.90,  11.10,
         11.30,  11.50,  11.70,  11.90,  12.10,  12.30,
         12.50,  12.70
    ]

    var centralFrequency: Double {
        get {
            return samplingFrequencyHertz
        }
    }
    var lambda: Double {
        get {
            return self.speedOfUltrasound / (1.0 * self.centralFrequency)
        }
    }

    var imageXPixelSpacing: Double {
        get {
            return lambda / 2.0 // Spacing between pixels in x_direction
        }
    }
    var imageZPixelSpacing: Double {
        get {
            return lambda / 2.0  // Spacing between pixels in z_direction
        }
    }

    var imageXStartInMM: Double {
        get {
            return VerasonicsFrameProcessor.defaultDelays.first!
        }
    }
    var imageXStopInMM: Double {
        get {
            return VerasonicsFrameProcessor.defaultDelays.last!
        }
    }
    var imageXPixelCount: Int {
        get {
            return Int(round((imageXStopInMM - imageXStartInMM) / imageXPixelSpacing))
        }
    }
    var imageZPixelCount: Int {
        get {
            return Int(round((imageZStopInMM - imageZStartInMM) / imageZPixelSpacing))
        }
    }

    var elementDelayValues: [Double]
    private var calculatedDelayValues: [ElementDelayData]?
    var elementDelayData: [ElementDelayData]? {
        get {
            let angle: Double = 0

            if self.calculatedDelayValues == nil {
                var xs = [Double](count: self.imageXPixelCount, repeatedValue: 0)
                for i in 0..<self.imageXPixelCount {
                    xs[i] = imageXStartInMM + Double(i) * self.imageXPixelSpacing
                }
                var zs = [Double](count: self.imageZPixelCount, repeatedValue: 0)
                for i in 0..<self.imageZPixelCount {
                    zs[i] = imageZStartInMM + Double(i) * self.imageZPixelSpacing
                }
                let xSineAlphas: [Double] = xs.map({ (x: Double) -> Double in
                    return x * sin(angle)
                })
                let zCosineAlphas: [Double] = zs.map({ (z: Double) -> Double in
                    return z * cos(angle)
                })
                let zSquareds: [Double] = zs.map({ (z: Double) -> Double in
                    return pow(z, 2)
                })

                let imagePixelCount = self.imageXPixelCount * self.imageZPixelCount
                self.calculatedDelayValues = [ElementDelayData]()
                self.calculatedDelayValues?.reserveCapacity(self.numberOfActiveTransducerElements)

                for (var element = 0; element < self.numberOfActiveTransducerElements; element++) {
                    var elementDelay = ElementDelayData(channelIdentifier: element, numberOfDelays: imagePixelCount)

                    print("Initializing \(self.imageXPixelCount * self.imageZPixelCount) delays for element \(element + 1)")
                    for(var x = 0; x < self.imageXPixelCount; x += 1) {
                        let xDifferenceSquared = pow(xs[x] - self.elementDelayValues[element], 2)

                        for (var z = 0; z < self.imageZPixelCount; z += 1) {
                            let delayIndex = x * self.imageZPixelCount + z
                            let tauReceive = sqrt(zSquareds[z] + xDifferenceSquared) / self.speedOfUltrasound
                            let tauEcho = (zCosineAlphas[z] + xSineAlphas[x]) / self.speedOfUltrasound

                            let delay = (tauEcho + tauReceive) * self.samplingFrequencyHertz + self.lensCorrection
                            elementDelay.delays[delayIndex] = delay
                        }
                    }
                    self.calculatedDelayValues?.append(elementDelay)
                }
            }

            return self.calculatedDelayValues
        }
    }

    init(withDelays: [Double])
    {
        self.elementDelayValues = withDelays
    }

    public func imageFromVerasonicsFrame(frame :VerasonicsFrame?) -> UIImage?
    {
        var image: UIImage?
        if frame != nil {
            let IQData = IQDataWithVerasonicsFrame(frame)!
            let complexImageVector = complexImageVectorWithIQData(IQData, width: self.imageXPixelCount, height: imageZPixelCount)!
            let imageAmplitudes = imageAmplitudesFromComplexImageVector(complexImageVector, width: self.imageXPixelCount, height: imageZPixelCount)
            // Because X and Z are swapped currently the image is rotated 90 degrees counter-clockwise. This should be corrected
            image = imageFromPixelValues(imageAmplitudes, width: self.imageZPixelCount, height: self.imageXPixelCount)
        }

        print("Frame \(frame?.identifier!) complete")
        return image
    }

    public func IQDataWithVerasonicsFrame(frame: VerasonicsFrame?) -> [ChannelData]?
    {
        var IQData: [ChannelData]?
        if let channelData = frame?.channelData {
            let numberOfElements = channelData.count
            IQData = [ChannelData]()
            for element in 0 ..< numberOfElements {
                let numberOfSamples = channelData[element].count / 2
                var elementIQData = ChannelData(channelIdentifier: element, numberOfSamples: numberOfSamples)
                for var sampleIndex = 0; sampleIndex < numberOfSamples; sampleIndex += 1 {
                    /*Getting the IQ data, the first sample is the real sample, the second sample is the
                    complex*/ // Room for improvement, why is it this way?
                    let sampleOffset = 2 * sampleIndex
                    let real = Double(channelData[element][sampleOffset])
                    let imaginary = Double(channelData[element][sampleOffset + 1])
                    elementIQData.real[sampleIndex] = real
                    elementIQData.imaginary[sampleIndex] = imaginary
                }
                IQData?.append(elementIQData)
            }
        }

        return IQData
    }

    public func complexImageVectorWithIQData(elementIQData: [ChannelData]?, width: Int, height: Int) -> ChannelData?
    {
        /* Interpolate the image*/
        var complexImageVector: ChannelData?
        if elementIQData != nil {
            let numberOfElements = elementIQData!.count
            let numberOfPixels = width * height

            complexImageVector = ChannelData(channelIdentifier: 0, numberOfSamples: numberOfPixels)
            var interpolatedImageWrapper = DSPDoubleSplitComplex(realp: &complexImageVector!.real, imagp: &complexImageVector!.imaginary)
            for elementIdentifier in 0 ..< numberOfElements {
                var aComplexImageVector = complexImageVectorForElement(elementIdentifier,
                    elementDelayDatum: self.elementDelayData![elementIdentifier],
                    elementIQDatum: elementIQData![elementIdentifier])
                var complexWrapper = DSPDoubleSplitComplex(realp: &aComplexImageVector.real, imagp: &aComplexImageVector.imaginary)
                vDSP_zvaddD(&interpolatedImageWrapper, 1, &complexWrapper, 1, &interpolatedImageWrapper, 1, UInt(numberOfPixels))
            }
        }

        return complexImageVector
    }

    public func complexImageVectorForElement(elementIdentifier: Int,
        elementDelayDatum: ElementDelayData,
        var elementIQDatum: ChannelData) -> ChannelData
    {
        let numberOfDelays = elementDelayDatum.delays.count
        let delays = elementDelayDatum.delays
        let x_ns = delays.map({
            (delay: Double) -> Double in
            return Double(floor(delay))
        })
        var x_n1s = delays.map({
            (delay: Double) -> Double in
            return Double(ceil(delay))
        })

        var alphas = [Double](count: numberOfDelays, repeatedValue: 0)
        vDSP_vsubD(delays, 1, &x_n1s, 1, &alphas, 1, UInt(numberOfDelays))

        var ones = [Double](count: numberOfDelays, repeatedValue: 1)
        var oneMinusAlphas = [Double](count: numberOfDelays, repeatedValue: 0)
        vDSP_vsubD(&alphas, 1, &ones, 1, &oneMinusAlphas, 1, UInt(numberOfDelays))

        var lowerReals = x_ns.enumerate().map {
            (index: Int, x_n: Double) -> Double in
            let index = Int(x_n)
            if (index < 400) {
                return elementIQDatum.real[index]
            } else {
                return 0
            }
        }
        var lowerImaginaries = x_ns.enumerate().map {
            (index: Int, x_n: Double) -> Double in
            let index = Int(x_n)
            if (index < 400) {
                return elementIQDatum.imaginary[index]
            } else {
                return 0
            }
        }
        var lowers = DSPDoubleSplitComplex(realp: &lowerReals, imagp: &lowerImaginaries)
        vDSP_zrvmulD(&lowers, 1, &alphas, 1, &lowers, 1, UInt(numberOfDelays))

        var upperReals = x_n1s.enumerate().map {
            (index: Int, x_n1: Double) -> Double in
            let index = Int(x_n1)
            if (index < 400) {
                return elementIQDatum.real[index]
            } else {
                return 0
            }
        }
        var upperImaginaries = x_n1s.enumerate().map {
            (index: Int, x_n1: Double) -> Double in
            let index = Int(x_n1)
            if (index < 400) {
                return elementIQDatum.imaginary[index]
            } else {
                return 0
            }
        }
        var uppers = DSPDoubleSplitComplex(realp: &upperReals, imagp: &upperImaginaries)
        vDSP_zrvmulD(&uppers, 1, &oneMinusAlphas, 1, &uppers, 1, UInt(numberOfDelays))

        var partBData = ChannelData(channelIdentifier: elementIQDatum.channelIdentifier, numberOfSamples: numberOfDelays)
        var partBs = DSPDoubleSplitComplex(realp: &partBData.real, imagp: &partBData.imaginary)
        vDSP_zvaddD(&lowers, 1, &uppers, 1, &partBs, 1, UInt(numberOfDelays))

        let elementDelays = elementDelayDatum.delays.map({
            (delay: Double) -> Double in
            return 2 * M_PI * self.centralFrequency * delay / self.samplingFrequencyHertz
        })

        var partARealConjugates = elementDelays.map({ (delay: Double) -> Double in
            let r = Foundation.exp(0.0)
            return r * cos(delay)
        })

        var partAImaginaryConjugates = elementDelays.map({ (delay: Double) -> Double in
            let r = Foundation.exp(0.0)
            return -1.0 * r * sin(delay)
        })
        var partAs = DSPDoubleSplitComplex(realp: &partARealConjugates, imagp: &partAImaginaryConjugates)

        var complexImageVector = ChannelData(channelIdentifier: elementIQDatum.channelIdentifier, numberOfSamples: numberOfDelays)
        var complexImageWrapper = DSPDoubleSplitComplex(realp: &complexImageVector.real, imagp: &complexImageVector.imaginary)
        vDSP_zvmulD(&partAs, 1, &partBs, 1, &complexImageWrapper, 1, UInt(numberOfDelays), 1)

        return complexImageVector
    }

    public func imageAmplitudesFromComplexImageVector(complexImageVector: ChannelData?, width: Int, height: Int) -> [UInt8]?
    {
        var imageIntensities: [UInt8]?
        if var imageVector = complexImageVector {
            var complexImageWrapper = DSPDoubleSplitComplex(realp: &imageVector.real, imagp: &imageVector.imaginary)

            // convert complex value to double
            let numberOfAmplitudes = width * height
            var imageAmplitudes = [Double](count: numberOfAmplitudes, repeatedValue: 0)
            vDSP_zvabsD(&complexImageWrapper, 1, &imageAmplitudes, 1, UInt(numberOfAmplitudes))

            let minimumValue = imageAmplitudes.minElement()!
            let maximumValue = imageAmplitudes.maxElement()!
            var scaledImageAmplitudes = imageAmplitudes.map({
                (imageAmplitude: Double) -> Double in
                return (((imageAmplitude - minimumValue) / (maximumValue - minimumValue)) * 255.0) + 1.0
            })

            var decibelValues = [Double](count: numberOfAmplitudes, repeatedValue: 0)
            var one: Double = 1;
            vDSP_vdbconD(&scaledImageAmplitudes, 1, &one, &decibelValues, 1, UInt(numberOfAmplitudes), 1)

            let decibelMinimumValues = decibelValues.minElement()!
            let decibelMaximumValues = decibelValues.maxElement()!
            var scaledDecibelValues = decibelValues.map({
                (decibelValue: Double) -> Double in
                return ((decibelValue - decibelMinimumValues) / (decibelMaximumValues - decibelMinimumValues)) * 255.0
            })

            // convert double to decibeL
            imageIntensities = [UInt8](count: numberOfAmplitudes, repeatedValue: 0)
            vDSP_vfixu8D(&scaledDecibelValues, 1, &imageIntensities!, 1, UInt(numberOfAmplitudes))
        }
        return imageIntensities
    }

    private func imageFromPixelValues(pixelValues: [UInt8]?, width: Int, height: Int) -> UIImage?
    {
        var image: UIImage?

        if (pixelValues != nil) {
            var data = pixelValues!

            let colorSpaceRef = CGColorSpaceCreateDeviceGray()

            let bitsPerComponent = 8
            let bytesPerPixel = 1
            let bitsPerPixel = bytesPerPixel * bitsPerComponent
            let bytesPerRow = bytesPerPixel * width
            let totalBytes = height * bytesPerRow

            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.None.rawValue)
                .union(CGBitmapInfo.ByteOrderDefault)

            let providerRef = CGDataProviderCreateWithData(nil, &data, totalBytes, nil)
            let imageRef = CGImageCreate(width,
                height,
                bitsPerComponent,
                bitsPerPixel,
                bytesPerRow,
                colorSpaceRef,
                bitmapInfo,
                providerRef,
                nil,
                false,
                CGColorRenderingIntent.RenderingIntentDefault)

            image = UIImage(CGImage: imageRef!, scale: 1.0, orientation: UIImageOrientation.Right)
        }

        return image
    }
}
