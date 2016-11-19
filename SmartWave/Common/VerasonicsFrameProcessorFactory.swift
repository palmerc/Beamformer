
import Foundation
import UIKit
import CoreGraphics
import Accelerate



public class VerasonicsFrameProcessorFactory: VerasonicsFrameProcessorBase
{
//    private var verasonicsFrameProcessorCPU: VerasonicsFrameProcessorCPU!
    private var verasonicsFrameProcessorMetal: VerasonicsFrameProcessorMetal!

    var calculatedChannelDelays: [Float]?
//    var elementPositions: [Float]?

    public init(withElementPositions elementPositions: [Float])
    {
        super.init()

        self.elementPositions = elementPositions
        let (x_ns, calculatedChannelDelays) = calculatedDelaysWithElementPositions(elementPositions)
        let (alphas, partAs) = self.processCalculatedDelays(calculatedChannelDelays!, centerFrequency: self.centralFrequency, samplingFrequencyHz: self.samplingFrequencyHz, numberOfElements: self.numberOfActiveTransducerElements)

        self.verasonicsFrameProcessorMetal = VerasonicsFrameProcessorMetal()
        self.verasonicsFrameProcessorMetal.partAs = partAs
        self.verasonicsFrameProcessorMetal.alphas = alphas
        self.verasonicsFrameProcessorMetal.x_ns = x_ns
    }


    // MARK: Main
    public func imageFromVerasonicsFrame(verasonicsFrame: VerasonicsFrame?, withCompletionHandler block: (image: UIImage) -> Void)
    {
        if let verasonicsFrame = verasonicsFrame {
//            let pixelCount = self.numberOfPixels;
//            let channelDataSampleCount = channelData!.complexSamples.count

//            var complexImageVector: [ComplexNumber]?
//            if self.verasonicsFrameProcessorMetal != nil {
//            self.verasonicsFrameProcessorMetal.samplesPerChannel = channelDataSampleCount
            self.verasonicsFrameProcessorMetal.complexVectorFromVerasonicsFrame(verasonicsFrame, withCompletionHandler: {
                (image: UIImage) in
                block(image: image)
            })
//            } else {
//                self.verasonicsFrameProcessorCPU.samplesPerChannel = channelDataSampleCount
//                complexImageVector = self.verasonicsFrameProcessorCPU.complexVectorFromChannelData(channelData)
//            }

//            let imageAmplitudes = self.verasonicsFrameProcessorCPU.imageAmplitudesFromComplexImageVector(complexImageVector, numberOfAmplitudes: pixelCount)
            print("Frame \(verasonicsFrame.identifier) complete")
        }
    }


    // MARK: Precompute values
    func calculatedDelaysWithElementPositions(elementPositions: [Float]?) -> ([Int]?, [Float]?)
    {
        var calculatedDelays: [Float]?
        var x_ns: [Int]?

        guard let elementPositions = elementPositions else {
            return (x_ns, calculatedDelays)
        }

        let angle: Float = 0

        var xIndices = [Int](count: self.numberOfPixels, repeatedValue: 0)
        var zIndices = [Int](count: self.numberOfPixels, repeatedValue: 0)
        var delayIndices = [Int](count: self.numberOfPixels, repeatedValue: 0)
        var xValues = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var zValues = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var zAngles = [Float](count: self.numberOfPixels, repeatedValue: 0)
        for index in 0 ..< self.numberOfPixels {
            let imageWidth = Int(self.imageSize.width)
            let xIndex = index % imageWidth
            let zIndex = index / imageWidth

            xIndices[index] = xIndex
            zIndices[index] = zIndex
            let imageDepth = Int(self.imageSize.height)
            delayIndices[index] = xIndex * imageDepth + zIndex

            let xValue = self.imageXStartInMM + Float(xIndex) * self.imageXPixelSpacing
            let zValue = self.imageZStartInMM + Float(zIndex) * self.imageZPixelSpacing

            // SOH CAH TOA
            let xSineAlpha = xValue * sin(angle)
            let zCosineAlpha = zValue * cos(angle)

            // Polar representation rho = x cos theta + y sin theta
            zAngles[index] = (xSineAlpha + zCosineAlpha) / self.speedOfUltrasoundInMMPerSecond

            xValues[index] = xValue
            zValues[index] = zValue
        }

        let numberOfDelays = self.numberOfActiveTransducerElements * self.numberOfPixels
        calculatedDelays = [Float](count: numberOfDelays, repeatedValue: 0)
        x_ns = [Int](count: numberOfDelays, repeatedValue: 0)

        for channelIdentifier in 0 ..< self.numberOfActiveTransducerElements {
            let elementPositionInMM = elementPositions[channelIdentifier]
            for index in 0 ..< self.numberOfPixels {
                let xDifferenceSquared = pow(xValues[index] - elementPositionInMM, 2)
                // tau = (z + sqrt(z^2 + (x - x_1)))/c
                let zAngle = zAngles[index]
                let tauReceive = sqrt(pow(zValues[index], 2) + xDifferenceSquared) / self.speedOfUltrasoundInMMPerSecond

                let delay = (zAngle + tauReceive) * self.samplingFrequencyHz + self.lensCorrection

                let lookupIndex = delayIndices[index]
                let delayIndex = channelIdentifier * self.numberOfPixels + lookupIndex
                calculatedDelays![delayIndex] = delay

                var x_n = Int(floor(delay))
                if x_n > self.samplesPerChannel {
                    x_n = -1
                }
                x_ns![delayIndex] = channelIdentifier * self.samplesPerChannel + x_n
            }
        }

        return (x_ns, calculatedDelays)
    }

    func processCalculatedDelays(perPixelDelay: [Float],
        centerFrequency: Float,
        samplingFrequencyHz: Float,
        numberOfElements: Int)
        -> (alphas: [Float], partAs: [ComplexNumber])
    {
        let x_n1s = perPixelDelay.map {
            (delay: Float) -> Float in
            return ceil(delay)
        }

        var alphas = [Float](count: perPixelDelay.count, repeatedValue: 0)
        vDSP_vsub(perPixelDelay, 1, x_n1s, 1, &alphas, 1, UInt(perPixelDelay.count))

        let shiftedPerPixelDelay = perPixelDelay.map({
            (delay: Float) -> Float in
            return 2 * Float(M_PI) * centerFrequency * delay / samplingFrequencyHz
        })

        let realConjugates = shiftedPerPixelDelay.map({
            (delay: Float) -> Float in
            let r = Foundation.exp(Float(0))
            return r * cos(delay)
        })

        let imaginaryConjugates = shiftedPerPixelDelay.map({
            (delay: Float) -> Float in
            let r = Foundation.exp(Float(0))
            return -1.0 * r * sin(delay)
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
                providerRef!,
                nil,
                false,
                CGColorRenderingIntent.RenderingIntentDefault)

            image = UIImage(CGImage: imageRef!, scale: 1.0, orientation: imageOrientation)
        }
        
        return image
    }
}
