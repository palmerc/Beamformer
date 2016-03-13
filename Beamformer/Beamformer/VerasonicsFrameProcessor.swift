
import Foundation
import UIKit
import CoreGraphics
import Accelerate



public class VerasonicsFrameProcessor: VerasonicsFrameProcessorBase
{
    private var verasonicsFrameProcessorCPU: VerasonicsFrameProcessorCPU!
    private var verasonicsFrameProcessorMetal: VerasonicsFrameProcessorMetal!

    var calculatedChannelDelays: [Float]?
    var elementPositions: [Float]?

    static let transducerElementPositionsInMMs: [Float] = [
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

    public init(withElementPositions elementPositions: [Float])
    {
        super.init()

        self.elementPositions = elementPositions
        let (x_ns, calculatedChannelDelays) = calculatedDelaysWithElementPositions(elementPositions)
        let (alphas, partAs) = self.processCalculatedDelays(calculatedChannelDelays!, centralFrequency: self.centralFrequency, samplingFrequencyHz: self.samplingFrequencyHz, numberOfElements: self.numberOfActiveTransducerElements)

        self.verasonicsFrameProcessorCPU = VerasonicsFrameProcessorCPU()
        self.verasonicsFrameProcessorCPU.partAs = partAs
        self.verasonicsFrameProcessorCPU.alphas = alphas
        self.verasonicsFrameProcessorCPU.x_ns = x_ns
        self.verasonicsFrameProcessorMetal = VerasonicsFrameProcessorMetal()
        self.verasonicsFrameProcessorMetal.partAs = partAs
        self.verasonicsFrameProcessorMetal.alphas = alphas
        self.verasonicsFrameProcessorMetal.x_ns = x_ns
    }


    // MARK: Main
    public func imageFromVerasonicsFrame(verasonicsFrame :VerasonicsFrame?) -> UIImage?
    {
        var image: UIImage?
        if let channelData: ChannelData? = verasonicsFrame!.channelData {
            let pixelCount = self.numberOfPixels;
            let channelDataSampleCount = channelData!.complexSamples.count

            var imageAmplitudes: [UInt8]?
//            var complexImageVector: [ComplexNumber]?
//            if self.verasonicsFrameProcessorMetal != nil {
//            self.verasonicsFrameProcessorMetal.samplesPerChannel = channelDataSampleCount
            imageAmplitudes = self.verasonicsFrameProcessorMetal.complexVectorFromChannelData(channelData)
//            } else {
//                self.verasonicsFrameProcessorCPU.samplesPerChannel = channelDataSampleCount
//                complexImageVector = self.verasonicsFrameProcessorCPU.complexVectorFromChannelData(channelData)
//            }

//            let imageAmplitudes = self.verasonicsFrameProcessorCPU.imageAmplitudesFromComplexImageVector(complexImageVector, numberOfAmplitudes: pixelCount)
            image = grayscaleImageFromPixelValues(imageAmplitudes,
                width: self.verasonicsFrameProcessorCPU.imageZPixelCount,
                height: self.verasonicsFrameProcessorCPU.imageXPixelCount,
                imageOrientation: .Right)

            print("Frame \(verasonicsFrame!.identifier!) complete")
        }

        return image
    }


    // MARK: Precompute values
    func calculatedDelaysWithElementPositions(elementPositions: [Float]?) -> ([Int]?, [Float]?)
    {
        var calculatedDelays: [Float]?
        var x_ns: [Int]?
        if (elementPositions != nil) {
            let angle: Float = 0
            var xs = [Float](count: self.imageXPixelCount, repeatedValue: 0)
            for index in 0..<self.imageXPixelCount {
                xs[index] = self.imageXStartInMM + Float(index) * self.imageXPixelSpacing
            }
            var zs = [Float](count: self.imageZPixelCount, repeatedValue: 0)
            for index in 0..<self.imageZPixelCount {
                zs[index] = self.imageZStartInMM + Float(index) * self.imageZPixelSpacing
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
            x_ns = [Int](count: numberOfDelays, repeatedValue: 0)
            for channelIdentifier in 0 ..< self.numberOfActiveTransducerElements {
                let channelDelays = elementPositions![channelIdentifier]
                for index in 0 ..< self.numberOfPixels {
                    let xDifferenceSquared = pow(unrolledXs[index] - channelDelays, 2)
                    let tauReceive = sqrt(zSquareds[index] + xDifferenceSquared) / self.speedOfUltrasound

                    let delay = (tauEchos[index] + tauReceive) * self.samplingFrequencyHz + self.lensCorrection

                    let lookupIndex = delayIndices[index]
                    let delayIndex = channelIdentifier * self.numberOfPixels + lookupIndex
                    calculatedDelays![delayIndex] = delay

                    var x_n = Int(floor(delay))
                    if x_n > self.samplesPerChannel {
                        x_n = -1
                    }
                    x_ns![delayIndex] = channelIdentifier * 400 + x_n
                }
            }
        }

        return (x_ns, calculatedDelays)
    }

    func processCalculatedDelays(calculatedDelays: [Float],
        centralFrequency: Float,
        samplingFrequencyHz: Float,
        numberOfElements: Int)
        -> (alphas: [Float], partAs: [ComplexNumber])
    {
        let x_ns = calculatedDelays.map({
            (channelDelay: Float) -> Float in
            return Float(floor(channelDelay))
        })

        let x_n1s = x_ns.map { (x_n: Float) -> Float in
            return x_n + 1
        }

        var alphas = [Float](count: calculatedDelays.count, repeatedValue: 0)
        vDSP_vsub(calculatedDelays, 1, x_n1s, 1, &alphas, 1, UInt(calculatedDelays.count))

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
        
        return (alphas, partAs)
    }



    // MARK: Image formation
    private func grayscaleImageFromPixelValues(pixelValues: [UInt8]?, width: Int, height: Int, imageOrientation: UIImageOrientation) -> UIImage?
    {
        var image: UIImage?

        if (pixelValues != nil) {
            let colorSpaceRef = CGColorSpaceCreateDeviceGray()

            let bitsPerComponent = 8
            let bytesPerPixel = 1
            let bitsPerPixel = bytesPerPixel * bitsPerComponent
            let bytesPerRow = bytesPerPixel * width
            let totalBytes = height * bytesPerRow

            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.None.rawValue)
                .union(CGBitmapInfo.ByteOrderDefault)

            let data = NSData(bytes: pixelValues!, length: totalBytes)
            let providerRef = CGDataProviderCreateWithCFData(data)

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

            image = UIImage(CGImage: imageRef!, scale: 1.0, orientation: imageOrientation)
        }
        
        return image
    }
}
