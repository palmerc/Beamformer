
import Foundation
import UIKit
import CoreGraphics
import Accelerate



public class VerasonicsFrameProcessor: NSObject
{
    private var verasonicsFrameProcessorCPU: VerasonicsFrameProcessorCPU!
    private var rawChannelDelays: [Float]!

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

    init(withDelays: [Float])
    {
        super.init()

        self.rawChannelDelays = withDelays
        self.verasonicsFrameProcessorCPU = VerasonicsFrameProcessorCPU(withElementPositions: VerasonicsFrameProcessor.transducerElementPositionsInMMs)
    }

    public func imageFromVerasonicsFrame(verasonicsFrame :VerasonicsFrame?) -> UIImage?
    {
        var image: UIImage?
        if let channelData: [ChannelData]? = verasonicsFrame!.channelData {
//            if self.metalDevice != nil {
//                let byteCount = 128 * 400 * sizeof((Float, Float))
//                if self.channelDataBufferPointer == nil {
//                    let (pointer, memoryWrapper) = setupSharedMemoryWithSize(byteCount)
//                    self.channelDataPointer = pointer
//
//                    let unsafePointer = UnsafeMutablePointer<[(Float, Float)]>(memoryWrapper)
//                    self.channelDataBufferPointer = UnsafeMutableBufferPointer(start: unsafePointer, count: channelData!.count)
//                }
//                if self.ultrasoundBitmapBufferPointer == nil {
//                    let (pointer, memoryWrapper) = setupSharedMemoryWithSize(byteCount)
//                    self.ultrasoundBitmapPointer = pointer
//
//                    let unsafeMutablePointer = UnsafeMutablePointer<[(Float, Float)]>(memoryWrapper)
//                    self.ultrasoundBitmapBufferPointer = UnsafeMutableBufferPointer(start: unsafeMutablePointer, count: byteCount)
//                }
//
//                image = processChannelDataWithMetal(channelData)
//            } else {

                let pixelCount = self.verasonicsFrameProcessorCPU.numberOfPixels
                let complexImageVector = self.verasonicsFrameProcessorCPU.complexVectorFromChannelData(channelData)
                let imageAmplitudes = self.verasonicsFrameProcessorCPU.imageAmplitudesFromComplexImageVector(complexImageVector, numberOfAmplitudes: pixelCount)
                image = grayscaleImageFromPixelValues(imageAmplitudes,
                    width: self.verasonicsFrameProcessorCPU.imageZPixelCount,
                    height: self.verasonicsFrameProcessorCPU.imageXPixelCount,
                    imageOrientation: .Right)
//            }

            print("Frame \(verasonicsFrame!.identifier!) complete")
        }

        return image
    }

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
