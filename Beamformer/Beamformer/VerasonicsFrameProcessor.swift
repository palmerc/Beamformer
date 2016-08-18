
import Foundation
import UIKit
import CoreGraphics
import Accelerate



public class VerasonicsFrameProcessor: VerasonicsFrameProcessorBase
{
//    private var verasonicsFrameProcessorCPU: VerasonicsFrameProcessorCPU!
    private var verasonicsFrameProcessorMetal: VerasonicsFrameProcessorMetal!

    var calculatedChannelDelays: [Float]?

    static let transducerElementSpacing: Float = 0.2
    static let transducerStartPosition: Float = -6.50
    static var transducerElementPositionsInMMs: [Float] {
        get {
            let postions = [Float](count: 128, repeatedValue: 0)
            let transducerElementPositions = postions.enumerate().map {
                (index: Int, _: Float) -> Float in
                return transducerStartPosition + Float(index) * transducerElementSpacing
            }

            return transducerElementPositions
        }
    }

//    static let transducerElementPositionsInMMs: [Float] = [
//        -12.70, -12.50, -12.30, -12.10, -11.90, -11.70,
//        -11.50, -11.30, -11.10, -10.90, -10.70, -10.50,
//        -10.30, -10.10,  -9.90,  -9.70,  -9.50,  -9.30,
//         -9.10,  -8.90,  -8.70,  -8.50,  -8.30,  -8.10,
//         -7.90,  -7.70,  -7.50,  -7.30,  -7.10,  -6.90,
//         -6.70,  -6.50,  -6.30,  -6.10,  -5.90,  -5.70,
//         -5.50,  -5.30,  -5.10,  -4.90,  -4.70,  -4.50,
//         -4.30,  -4.10,  -3.90,  -3.70,  -3.50,  -3.30,
//         -3.10,  -2.90,  -2.70,  -2.50,  -2.30,  -2.10,
//         -1.90,  -1.70,  -1.50,  -1.30,  -1.10,  -0.90,
//         -0.70,  -0.50,  -0.30,  -0.10,   0.10,   0.30,
//          0.50,   0.70,   0.90,   1.10,   1.30,   1.50,
//          1.70,   1.90,   2.10,   2.30,   2.50,   2.70,
//          2.90,   3.10,   3.30,   3.50,   3.70,   3.90,
//          4.10,   4.30,   4.50,   4.70,   4.90,   5.10,
//          5.30,   5.50,   5.70,   5.90,   6.10,   6.30,
//          6.50,   6.70,   6.90,   7.10,   7.30,   7.50,
//          7.70,   7.90,   8.10,   8.30,   8.50,   8.70,
//          8.90,   9.10,   9.30,   9.50,   9.70,   9.90,
//         10.10,  10.30,  10.50,  10.70,  10.90,  11.10,
//         11.30,  11.50,  11.70,  11.90,  12.10,  12.30,
//         12.50,  12.70
//    ]

    public init(withElementPositions elementPositions: [Float])
    {
        super.init()

        self.elementPositions = elementPositions
        let (sampleLookup, calculatedChannelDelays) = calculatedDelaysWithElementPositions(elementPositions)
        let (alphas, partAs) = self.processCalculatedDelays(calculatedChannelDelays!, numberOfElements: self.numberOfActiveTransducerElements)

        self.verasonicsFrameProcessorMetal = VerasonicsFrameProcessorMetal()
        self.verasonicsFrameProcessorMetal.partAs = partAs
        self.verasonicsFrameProcessorMetal.alphas = alphas
        self.verasonicsFrameProcessorMetal.x_ns = sampleLookup
    }


    // MARK: Main
    public func imageFromVerasonicsFrame(verasonicsFrame :VerasonicsFrame?, withCompletionHandler handler: (image: UIImage) -> Void)
    {
        guard let frame = verasonicsFrame else {
            return
        }

//            let pixelCount = self.numberOfPixels;
//            let channelDataSampleCount = channelData!.complexSamples.count

//            var complexImageVector: [ComplexNumber]?
//            if self.verasonicsFrameProcessorMetal != nil {
//            self.verasonicsFrameProcessorMetal.samplesPerChannel = channelDataSampleCount
        self.verasonicsFrameProcessorMetal.complexVectorFromVerasonicsFrame(frame,
                                                                            withCompletionHandler: {
            (image: UIImage) in
            handler(image: image)
        })
//            } else {
        //                self.verasonicsFrameProcessorCPU.samplesPerChannel = channelDataSampleCount
//                complexImageVector = self.verasonicsFrameProcessorCPU.complexVectorFromChannelData(channelData)
//            }

//            let imageAmplitudes = self.verasonicsFrameProcessorCPU.imageAmplitudesFromComplexImageVector(complexImageVector, numberOfAmplitudes: pixelCount)
        print("Frame \(frame.identifier) complete")
    }


    // MARK: Precompute values
    func calculatedDelaysWithElementPositions(elementPositions: [Float]?) -> ([Int]?, [Float]?)
    {
        var calculatedDelays: [Float]?
        var sampleLookup: [Int]?

        guard let elementPositions = elementPositions else {
            print("Element positions are not initialized.")
            return (sampleLookup, calculatedDelays)
        }

        let numberOfDelays = self.numberOfActiveTransducerElements * self.numberOfPixels
        var calculatedDelaysInternal = [Float](count: numberOfDelays, repeatedValue: 0)
        var sampleIndices = [Int](count: numberOfDelays, repeatedValue: 0)

        let angle: Float = 0

        var unrolledXs = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var unrolledZs = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var tauSends = [Float](count: self.numberOfPixels, repeatedValue: 0)
        for pixelIndex in 0 ..< self.numberOfPixels {
            let xIndex = pixelIndex % Int(self.imageSize.width)
            let zIndex = pixelIndex / Int(self.imageSize.width)
            let x = self.imageXStartInMM + Float(xIndex) * self.imageXPixelSpacing
            let z = self.imageZStartInMM + Float(zIndex) * self.imageZPixelSpacing
            unrolledXs[pixelIndex] = x
            unrolledZs[pixelIndex] = z
            tauSends[pixelIndex] = x * sin(angle) + z * cos(angle)
        }

        for channelIdentifier in 0 ..< self.numberOfActiveTransducerElements {
            let elementPosition = elementPositions[channelIdentifier]
            for pixelIndex in 0 ..< self.numberOfPixels {
                let channelPixelIndex = channelIdentifier * self.numberOfPixels + pixelIndex

                let x = unrolledXs[pixelIndex]
                let z = unrolledZs[pixelIndex]
                let xDifferenceSquared = pow(x - elementPosition, 2)
                let zSquared = pow(z, 2)

                let tauSend = tauSends[pixelIndex]
                let tauReceive = sqrt(zSquared + xDifferenceSquared)
                let tau = (tauSend + tauReceive) / self.speedOfUltrasoundInMMPerSecond

                let delay = tau * self.samplingFrequencyHz + self.lensCorrection

                var sampleOffset = Int(floor(delay))
                if sampleOffset < 0 {
                    sampleOffset = 0
                } else if sampleOffset >= self.samplesPerChannel {
                    sampleOffset = self.numberOfActiveTransducerElements - 1
                }

                sampleIndices[channelPixelIndex] = channelIdentifier * self.samplesPerChannel + sampleOffset
                calculatedDelaysInternal[channelPixelIndex] = delay
            }

            sampleLookup = sampleIndices
            calculatedDelays = calculatedDelaysInternal
        }

        return (sampleLookup, calculatedDelays)
    }

    func processCalculatedDelays(calculatedDelays: [Float],
        numberOfElements: Int)
        -> (alphas: [Float], partAs: [ComplexNumber])
    {
        let ceilingOfDelays = calculatedDelays.map({
            (delay: Float) -> Float in
            return floor(delay) + 1
        })

        var alphas = [Float](count: calculatedDelays.count, repeatedValue: 0)
        vDSP_vsub(calculatedDelays, 1, ceilingOfDelays, 1, &alphas, 1, UInt(calculatedDelays.count))

        let shiftedDelays = calculatedDelays.map({
            (channelDelay: Float) -> Float in
            return 2 * Float(M_PI) * self.centralFrequency * channelDelay / self.samplingFrequencyHz
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

        let IQComplexFrequencyShifts = ComplexVector(reals: realConjugates, imaginaries: imaginaryConjugates).complexNumbers!
        
        return (alphas, IQComplexFrequencyShifts)
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
