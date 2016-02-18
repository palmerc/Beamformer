
import Foundation
import UIKit
import CoreGraphics
import Accelerate
import Metal



public class VerasonicsFrameProcessor: NSObject
{
    private let speedOfUltrasound: Float = 1540 * 1000
    private let samplingFrequencyHertz: Float = 7813000
    private let lensCorrection: Float = 14.14423409
    private let numberOfTransducerElements: Int = 192
    private let numberOfActiveTransducerElements: Int = 128
    private let imageZStartInMM: Float = 0.0
    private let imageZStopInMM: Float = 50.0

    private var channelDataPointer: UnsafeMutablePointer<Void> = nil
    private var channelDataBufferPointer: UnsafeMutableBufferPointer<[(Float, Float)]>?

    private var ultrasoundBitmapPointer: UnsafeMutablePointer<Void> = nil
    private var ultrasoundBitmapBufferPointer: UnsafeMutableBufferPointer<[(Float, Float)]>?

    // F***ing Metal
    private var metalDevice: MTLDevice! = nil
    private var metalDefaultLibrary: MTLLibrary! = nil
    private var metalCommandQueue: MTLCommandQueue! = nil
    private var metalKernelFunction: MTLFunction!
    private var metalPipelineState: MTLComputePipelineState!
    private var errorFlag:Bool = false

    private var particle_threadGroupCount:MTLSize!
    private var particle_threadGroups:MTLSize!

    private var frameStartTime = CFAbsoluteTimeGetCurrent()

    private var region: MTLRegion!
    private var textureA: MTLTexture!
    private var textureB: MTLTexture!
    private var queue: dispatch_queue_t!
    


    static let defaultDelays: [Float] = [
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

    var centralFrequency: Float {
        get {
            return samplingFrequencyHertz
        }
    }
    var lambda: Float {
        get {
            return self.speedOfUltrasound / (1.0 * self.centralFrequency)
        }
    }

    var imageXPixelSpacing: Float {
        get {
            return lambda / 2.0 // Spacing between pixels in x_direction
        }
    }
    var imageZPixelSpacing: Float {
        get {
            return lambda / 2.0  // Spacing between pixels in z_direction
        }
    }

    var imageXStartInMM: Float {
        get {
            return VerasonicsFrameProcessor.defaultDelays.first!
        }
    }
    var imageXStopInMM: Float {
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
    var numberOfPixels: Int {
        return self.channelDelays!.first!.delays.count
    }

    var x_ns: [[Float]]? = nil
    var x_n1s: [[Float]]? = nil
    var alphas: [[Float]]? = nil
    var oneMinusAlphas: [[Float]]? = nil
    var partAs: [ComplexVector]? = nil
    var rawChannelDelays: [Float]
    private var _calculatedChannelDelays: [ChannelDelay]?
    var channelDelays: [ChannelDelay]? {
        get {
            let angle: Float = 0

            if self._calculatedChannelDelays == nil {
                var xs = [Float](count: self.imageXPixelCount, repeatedValue: 0)
                for i in 0..<self.imageXPixelCount {
                    xs[i] = imageXStartInMM + Float(i) * self.imageXPixelSpacing
                }
                var zs = [Float](count: self.imageZPixelCount, repeatedValue: 0)
                for i in 0..<self.imageZPixelCount {
                    zs[i] = imageZStartInMM + Float(i) * self.imageZPixelSpacing
                }

                var calculatedDelayValues = [ChannelDelay]()
                calculatedDelayValues.reserveCapacity(self.numberOfActiveTransducerElements)

                let numberOfPixels = self.imageXPixelCount * self.imageZPixelCount
                var xIndices = [Int](count: numberOfPixels, repeatedValue: 0)
                var zIndices = [Int](count: numberOfPixels, repeatedValue: 0)
                var delayIndices = [Int](count: numberOfPixels, repeatedValue: 0)
                var zSquareds = [Float](count: numberOfPixels, repeatedValue: 0)
                var unrolledXs = [Float](count: numberOfPixels, repeatedValue: 0)
                var xSineAlphas = [Float](count: numberOfPixels, repeatedValue: 0)
                var zCosineAlphas = [Float](count: numberOfPixels, repeatedValue: 0)
                for index in 0..<numberOfPixels {
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

                for channelIdentifier in 0..<self.numberOfActiveTransducerElements {
                    var channelDelay = ChannelDelay(channelIdentifier: channelIdentifier, numberOfDelays: numberOfPixels)
                    let channelDelays = self.rawChannelDelays[channelIdentifier]
                    print("Initializing \(self.imageXPixelCount * self.imageZPixelCount) delays for channel \(channelIdentifier + 1)")
                    for index in 0..<numberOfPixels {
                        let xDifferenceSquared = pow(unrolledXs[index] - channelDelays, 2)
                        let tauReceive = sqrt(zSquareds[index] + xDifferenceSquared) / self.speedOfUltrasound

                        let delay = (tauEchos[index] + tauReceive) * self.samplingFrequencyHertz + self.lensCorrection

                        let delayIndex = delayIndices[index]
                        channelDelay.delays[delayIndex] = delay
                    }
                    calculatedDelayValues.append(channelDelay)
                }

                for channelIdentifier in 0..<self.numberOfActiveTransducerElements {
                    let channelDelays = calculatedDelayValues[channelIdentifier].delays
                    let numberOfDelays = channelDelays.count

                    let x_ns = channelDelays.map({
                        (channelDelay: Float) -> Float in
                        return Float(floor(channelDelay))
                    })
                    let x_n1s = channelDelays.map({
                        (channelDelay: Float) -> Float in
                        return Float(ceil(channelDelay))
                    })

                    var alphas = [Float](count: numberOfDelays, repeatedValue: 0)
                    vDSP_vsub(channelDelays, 1, x_n1s, 1, &alphas, 1, UInt(numberOfDelays))

                    let ones = [Float](count: numberOfDelays, repeatedValue: 1)
                    var oneMinusAlphas = [Float](count: numberOfDelays, repeatedValue: 0)
                    vDSP_vsub(alphas, 1, ones, 1, &oneMinusAlphas, 1, UInt(numberOfDelays))

                    let calculatedDelays = channelDelays.map({
                        (channelDelay: Float) -> Float in
                        return 2 * Float(M_PI) * self.centralFrequency * channelDelay / self.samplingFrequencyHertz
                    })

                    let realConjugates = calculatedDelays.map({
                        (calculatedDelay: Float) -> Float in
                        let r = Foundation.exp(Float(0))
                        return r * cos(calculatedDelay)
                    })

                    let imaginaryConjugates = calculatedDelays.map({
                        (calculatedDelay: Float) -> Float in
                        let r = Foundation.exp(Float(0))
                        return -1.0 * r * sin(calculatedDelay)
                    })
                    
                    let partAs = ComplexVector(reals: realConjugates, imaginaries: imaginaryConjugates)

                    self.x_ns![channelIdentifier] = x_ns
                    self.x_n1s![channelIdentifier] = x_n1s
                    self.alphas![channelIdentifier] = alphas
                    self.oneMinusAlphas![channelIdentifier] = oneMinusAlphas
                    self.partAs![channelIdentifier] = partAs
                }

                self._calculatedChannelDelays = calculatedDelayValues
            }

            return self._calculatedChannelDelays
        }
    }

    init(withDelays: [Float])
    {
        self.rawChannelDelays = withDelays
        self.x_ns = [[Float]](count: self.numberOfActiveTransducerElements, repeatedValue: [Float]())
        self.x_n1s = [[Float]](count: self.numberOfActiveTransducerElements, repeatedValue: [Float]())
        self.alphas = [[Float]](count: self.numberOfActiveTransducerElements, repeatedValue: [Float]())
        self.oneMinusAlphas = [[Float]](count: self.numberOfActiveTransducerElements, repeatedValue: [Float]())
        self.partAs = [ComplexVector](count: self.numberOfActiveTransducerElements, repeatedValue: ComplexVector())

        super.init()

        self.queue = dispatch_queue_create("no.uio.Beamformer", DISPATCH_QUEUE_CONCURRENT)
        let (metalDevice, metalLibrary, metalCommandQueue) = self.setupMetalDevice()
        if metalDevice != nil {
            let (metalKernelFunction, metalPipelineState) = self.setupShaderInMetalPipelineWithName("echo", withDevice: metalDevice, inLibrary: metalLibrary)

            self.metalDevice = metalDevice
            self.metalKernelFunction = metalKernelFunction
            self.metalPipelineState = metalPipelineState
            self.metalDefaultLibrary = metalLibrary
            self.metalCommandQueue = metalCommandQueue
        } else {
            print("Failed to find a Metal device. Processing will be performed on CPU.")
        }
    }

    deinit
    {
        if self.channelDataPointer != nil {
            free(self.channelDataPointer)
        }
        if self.ultrasoundBitmapPointer != nil {
            free(self.ultrasoundBitmapPointer)
        }
    }

    public func imageFromVerasonicsFrame(verasonicsFrame :VerasonicsFrame?) -> UIImage?
    {
        var image: UIImage?
        if let channelData: [ChannelData]? = verasonicsFrame!.channelData {
            if self.metalDevice != nil {
                let byteCount = 128 * 400 * sizeof((Float, Float))
                if self.channelDataBufferPointer == nil {
                    let (pointer, memoryWrapper) = setupSharedMemoryWithSize(byteCount)
                    self.channelDataPointer = pointer

                    let unsafePointer = UnsafeMutablePointer<[(Float, Float)]>(memoryWrapper)
                    self.channelDataBufferPointer = UnsafeMutableBufferPointer(start: unsafePointer, count: channelData!.count)
                }
                if self.ultrasoundBitmapBufferPointer == nil {
                    let (pointer, memoryWrapper) = setupSharedMemoryWithSize(byteCount)
                    self.ultrasoundBitmapPointer = pointer

                    let unsafeMutablePointer = UnsafeMutablePointer<[(Float, Float)]>(memoryWrapper)
                    self.ultrasoundBitmapBufferPointer = UnsafeMutableBufferPointer(start: unsafeMutablePointer, count: byteCount)
                }

                image = processChannelDataWithMetal(channelData)
            } else {
                let complexImageVector = complexImageVectorWithChannelData(channelData)!
                let imageAmplitudes = imageAmplitudesFromComplexImageVector(complexImageVector)
                image = grayscaleImageFromPixelValues(imageAmplitudes,
                    width: self.imageZPixelCount,
                    height: self.imageXPixelCount,
                    imageOrientation: .Right)
            }

            print("Frame \(verasonicsFrame!.identifier!) complete")
        }

        return image
    }

    public func complexImageVectorWithChannelData(channelData: [ChannelData]?) -> ComplexVector?
    {
        /* Interpolate the image*/
        var complexImageVector: ComplexVector?
        if channelData != nil {
            let numberOfChannels = channelData!.count

            complexImageVector = ComplexVector(count: self.numberOfPixels, repeatedValue: 0)
            var complexImageVectorWrapper = DSPSplitComplex(realp: &complexImageVector!.reals!, imagp: &complexImageVector!.imaginaries!)

            dispatch_apply(numberOfChannels, self.queue, {
                (channelIdentifier: Int) -> Void in
                let channelDatum = channelData![channelIdentifier]
                var aComplexImageVector = self.complexImageVectorWithChannelDatum(channelDatum)
                var aComplexImageVectorWrapper = DSPSplitComplex(realp: &aComplexImageVector.reals!, imagp: &aComplexImageVector.imaginaries!)
                vDSP_zvadd(&aComplexImageVectorWrapper, 1, &complexImageVectorWrapper, 1, &complexImageVectorWrapper, 1, UInt(self.numberOfPixels))
            })
        }

        return complexImageVector
    }

    public func complexImageVectorWithChannelDatum(channelDatum: ChannelData) -> ComplexVector
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

        var upperReals = x_n1s![channelIdentifier].enumerate().map {
            (index: Int, x_n1: Float) -> Float in
            let index = Int(x_n1)
            if (index < numberOfSamplesPerChannel) {
                return complexChannelVector.reals![index]
            } else {
                return 0
            }
        }
        var upperImaginaries = x_n1s![channelIdentifier].enumerate().map {
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
        var complexImageVector = ComplexVector(count: numberOfDelays, repeatedValue: 0)
        var complexImageWrapper = DSPSplitComplex(realp: &complexImageVector.reals!, imagp: &complexImageVector.imaginaries!)
        vDSP_zvmul(&partAWrapper, 1, &partBs, 1, &complexImageWrapper, 1, UInt(numberOfDelays), 1)

        return complexImageVector
    }

    public func imageAmplitudesFromComplexImageVector(complexImageVector: ComplexVector?) -> [UInt8]?
    {
        var imageIntensities: [UInt8]?
        if complexImageVector != nil {
            let imageVector = complexImageVector!
            var reals = imageVector.reals!
            var imaginaries = imageVector.imaginaries!
            var complexImageWrapper = DSPSplitComplex(realp: &reals, imagp: &imaginaries)

            // convert complex value to double
            let numberOfAmplitudes = self.numberOfPixels
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

    private func setupMetalDevice() -> (metalDevice: MTLDevice?,
        metalLibrary: MTLLibrary?,
        metalCommandQueue: MTLCommandQueue?)
    {
        let metalDevice: MTLDevice? = MTLCreateSystemDefaultDevice()
        let metalLibrary = metalDevice?.newDefaultLibrary()
        let metalCommandQueue = metalDevice?.newCommandQueue()

        return (metalDevice, metalLibrary, metalCommandQueue)
    }

    private func setupShaderInMetalPipelineWithName(kernelFunctionName: String, withDevice metalDevice: MTLDevice?, inLibrary metalLibrary: MTLLibrary?) ->
        (metalKernelFunction: MTLFunction?,
        metalPipelineState: MTLComputePipelineState?)
    {
            let metalKernelFunction: MTLFunction? = metalLibrary?.newFunctionWithName(kernelFunctionName)

            let computePipeLineDescriptor = MTLComputePipelineDescriptor()
            computePipeLineDescriptor.computeFunction = metalKernelFunction

            var metalPipelineState: MTLComputePipelineState? = nil
            do {
                metalPipelineState = try metalDevice?.newComputePipelineStateWithFunction(metalKernelFunction!)
            } catch let error as NSError {
                print("Compute pipeline state acquisition failed. \(error.localizedDescription)")
            }

            return (metalKernelFunction, metalPipelineState)
    }

    private func setupSharedMemoryWithSize(byteCount: Int) ->
        (pointer: UnsafeMutablePointer<Void>,
        memoryWrapper: COpaquePointer)
    {
        let memoryAlignment = 0x1000
        var memory: UnsafeMutablePointer<Void> = nil
        posix_memalign(&memory, memoryAlignment, byteSizeWithAlignment(memoryAlignment, size: byteCount))

        let memoryWrapper = COpaquePointer(memory)

        return (memory, memoryWrapper)
    }

    private func byteSizeWithAlignment(alignment: Int, size: Int) -> Int
    {
        return Int(ceil(Float(size) / Float(alignment))) * alignment
    }

    private func processChannelDataWithMetal(channelData: [ChannelData]?) -> UIImage?
    {

        let byteCount = 128 * 400 * sizeof((Float, Float))
        let channelAlignedByteCount = byteSizeWithAlignment(0x1000, size: byteCount)

        let imageWidth = self.imageXPixelCount
        let imageHeight = self.imageZPixelCount
        let imageAlignedByteCount = byteSizeWithAlignment(0x1000, size: imageWidth * imageHeight * sizeof(UInt8))

        let metalCommandBuffer = self.metalCommandQueue.commandBuffer()
        let commandEncoder = metalCommandBuffer.computeCommandEncoder()

        if metalPipelineState != nil {
            commandEncoder.setComputePipelineState(metalPipelineState!)
        }

        for index in self.channelDataBufferPointer!.startIndex ..< self.channelDataBufferPointer!.endIndex
        {
            let complexObject = channelData![index].complexVector.zip
            self.channelDataBufferPointer![index] = complexObject!
        }

        let inputVector = self.metalDevice.newBufferWithBytesNoCopy(self.channelDataPointer, length: channelAlignedByteCount, options: MTLResourceOptions(rawValue: 0), deallocator: nil)
        commandEncoder.setBuffer(inputVector, offset: 0, atIndex: 0)

        let outputVector = self.metalDevice.newBufferWithBytesNoCopy(self.ultrasoundBitmapPointer, length: channelAlignedByteCount, options: MTLResourceOptions(rawValue: 0), deallocator: nil)
        commandEncoder.setBuffer(outputVector, offset: 0, atIndex: 1)

        let threadExecutionWidth = metalPipelineState!.threadExecutionWidth
        let threadGroupCount = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        let threadGroups = MTLSize(width: 128 / threadGroupCount.width, height: 1, depth:1)

        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        metalCommandBuffer.commit()
        metalCommandBuffer.waitUntilCompleted()

        var copiedPixelValues = [(Float, Float)](count: byteCount, repeatedValue: (0, 0))
        let data = NSData(bytesNoCopy: outputVector.contents(), length: byteCount, freeWhenDone: false)
        data.getBytes(&copiedPixelValues, length:byteCount)

//
//        let image = self.grayscaleImageFromPixelValues(copiedPixelValues, width: width, height: height, imageOrientation: UIImageOrientation.Up)

        return nil
    }

    private func pixelValuesFromImage(imageRef: CGImage?) -> (pixelValues: [UInt8]?, width: Int, height: Int)
    {
        var width = 0
        var height = 0
        var pixelValues: [UInt8]?
        if imageRef != nil {
            width = CGImageGetWidth(imageRef!)
            height = CGImageGetHeight(imageRef!)
            let bitsPerComponent = 8
            let bytesPerPixel = 1
            let bytesPerRow = bytesPerPixel * width
            let totalBytes = height * bytesPerRow

            pixelValues = [UInt8](count: totalBytes, repeatedValue: 0)

            let colorSpaceRef = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.None.rawValue)
                .union(CGBitmapInfo.ByteOrderDefault)
            let contextRef = CGBitmapContextCreate(&pixelValues!, width, height, bitsPerComponent, bytesPerRow, colorSpaceRef, bitmapInfo.rawValue)
            CGContextDrawImage(contextRef, CGRectMake(0.0, 0.0, CGFloat(width), CGFloat(height)), imageRef)
        }
        
        return (pixelValues, width, height)
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
