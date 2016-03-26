import Foundation
import UIKit
import Metal
import Accelerate

struct ImageAmplitudesParameters {
    var minimumValue: Float
    var maximumValue: Float
}

struct BeamformerParameters {
    var numberOfChannels: Int32
    var numberOfSamplesPerChannel: Int32
    var pixelCount: Int32
}

private let kInflightCommandBuffers = 1



public class VerasonicsFrameProcessorMetal: VerasonicsFrameProcessorBase
{
    private var isInitializationComplete = false
    private var channelDataParametersMetalBuffer: MTLBuffer?
    private var imageAmplitudesParametersMetalBuffer: MTLBuffer?
    private var channelDataMetalBuffers: [MTLBuffer]?
    private var partAsMetalBuffer: MTLBuffer?
    private var alphasMetalBuffer: MTLBuffer?
    private var xnsMetalBuffer: MTLBuffer?
    private var imageAmplitudesMetalBuffer: MTLBuffer?
    private var imageIntensitiesMetalBuffer: MTLBuffer?

    private var metalDevice: MTLDevice! = nil
    private var metalDefaultLibrary: MTLLibrary! = nil
    private var metalCommandQueue: MTLCommandQueue! = nil

    private var metalChannelDataKernelFunction: MTLFunction!
    private var metalChannelDataPipelineState: MTLComputePipelineState!
    private var metalDecibelValueKernelFunction: MTLFunction!
    private var metalDecibelValuePipelineState: MTLComputePipelineState!

    private var errorFlag:Bool = false

    private var particle_threadGroupCount:MTLSize!
    private var particle_threadGroups:MTLSize!

    private var region: MTLRegion!
    private var textureA: MTLTexture!
    private var textureB: MTLTexture!

    private var amplitudeValues: [Float]!
    private var pixelValues: [UInt8]!

    private var queue: dispatch_queue_t!
    private let queueName = "no.uio.Beamformer"

    private var computeFrameCycle: Int = 0
    private var inflightSemaphore: dispatch_semaphore_t



    // MARK: Object lifecycle
    override init()
    {
        self.computeFrameCycle = 0
        self.inflightSemaphore = dispatch_semaphore_create(kInflightCommandBuffers)

        super.init()

        self.amplitudeValues = [Float](count: self.numberOfPixels, repeatedValue: 0)
        self.pixelValues = [UInt8](count: self.numberOfPixels, repeatedValue: 0)

        let (metalDevice, metalLibrary, metalCommandQueue) = self.setupMetalDevice()
        if let metalDevice = metalDevice, metalLibrary = metalLibrary, metalCommandQueue = metalCommandQueue {
            let (metalChannelDataKernelFunction, metalChannelDataPipelineState) = self.setupShaderInMetalPipelineWithName("processChannelData", withDevice: metalDevice, inLibrary: metalLibrary)
            self.metalChannelDataKernelFunction = metalChannelDataKernelFunction
            self.metalChannelDataPipelineState = metalChannelDataPipelineState

            let (metalDecibelValueKernelFunction, metalDecibelValuePipelineState) = self.setupShaderInMetalPipelineWithName("processDecibelValues", withDevice: metalDevice, inLibrary: metalLibrary)
            self.metalDecibelValueKernelFunction = metalDecibelValueKernelFunction
            self.metalDecibelValuePipelineState = metalDecibelValuePipelineState

            self.metalDevice = metalDevice
            self.metalDefaultLibrary = metalLibrary
            self.metalCommandQueue = metalCommandQueue

            self.queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        } else {
            print("Failed to find a Metal device. Processing will be performed on CPU.")
        }
    }

    deinit
    {
//        if self.channelDataPointer != nil {
//            self.channelDataPointer.destroy()
//        }
//        if self.ultrasoundBitmapPointer != nil {
//            self.ultrasoundBitmapPointer.destroy()
//        }
    }

    // MARK: Metal setup

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

    // MARK:

    public func complexVectorFromChannelData(channelData: ChannelData?, withCompletionHandler block: (image: UIImage) -> ())
    {
        if let channelData = channelData {
            if !self.isInitializationComplete {
                initializeBuffersWithSampleCount(channelData.complexSamples.count)
            }

            if let imageIntensitiesMetalBuffer = self.imageIntensitiesMetalBuffer {
                let metalCommandBuffer = self.metalCommandQueue.commandBuffer()
                dispatch_semaphore_wait(self.inflightSemaphore, DISPATCH_TIME_FOREVER)
                self.processChannelData(channelData, withCommandBuffer: metalCommandBuffer)
                self.processDecibelValues(metalCommandBuffer)
                metalCommandBuffer.addCompletedHandler({ _ in
                    let image = self.grayscaleImageFromPixelValues(imageIntensitiesMetalBuffer.contents(), width: self.imageZPixelCount, height: self.imageXPixelCount, imageOrientation: UIImageOrientation.LeftMirrored)
                    dispatch_semaphore_signal(self.inflightSemaphore)
                    if let image = image {
                        block(image: image)
                    }
                })
                metalCommandBuffer.commit()
            }
        }
    }

    private func grayscaleImageFromPixelValues(pixelValues: UnsafePointer<Void>?, width: Int, height: Int, imageOrientation: UIImageOrientation) -> UIImage?
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

    private func initializeBuffersWithSampleCount(sampleValueCount: Int)
    {
        if self.imageAmplitudesParametersMetalBuffer == nil {
            let byteCount = sizeof(ImageAmplitudesParameters)
            self.imageAmplitudesParametersMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: .StorageModeShared)
        }
        if self.channelDataParametersMetalBuffer == nil {
            let byteCount = sizeof(BeamformerParameters)
            let options = MTLResourceOptions.StorageModeShared.union(.CPUCacheModeWriteCombined)
            self.channelDataParametersMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: options)
        }

        if self.channelDataMetalBuffers == nil {
            var metalBuffers = [MTLBuffer]()
            for index in 0 ..< kInflightCommandBuffers {
                let byteCount = sampleValueCount * sizeof(Int16)
                let options = MTLResourceOptions.StorageModeShared.union(.CPUCacheModeWriteCombined)
                let channelDataMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: options)
                channelDataMetalBuffer.label = "Channel Data Buffer \(index)"
                metalBuffers.append(channelDataMetalBuffer)
            }

            if metalBuffers.count > 0 {
                self.channelDataMetalBuffers = metalBuffers
            }
        }

        if self.partAsMetalBuffer == nil {
            let count = self.partAs!.count
            let byteCount = count * sizeof(ComplexNumber)
            let options = MTLResourceOptions.StorageModeShared.union(.CPUCacheModeWriteCombined)
            self.partAsMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: options)
        }

        if let partAs = self.partAs, partAsMetalBuffer = self.partAsMetalBuffer {
            let count = Int32(partAs.count) * 2
            cblas_scopy(count, UnsafePointer<Float>(partAs), 1, UnsafeMutablePointer<Float>(partAsMetalBuffer.contents()), 1)
        }

        if self.alphasMetalBuffer == nil {
            let count = self.alphas!.count
            let byteCount = count * sizeof(Float)
            let options = MTLResourceOptions.StorageModeShared.union(.CPUCacheModeWriteCombined)
            self.alphasMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: options)
        }

        if let alphas = self.alphas, alphasMetalBuffer = self.alphasMetalBuffer {
            let count = Int32(alphas.count)
            cblas_scopy(count, alphas, 1, UnsafeMutablePointer<Float>(alphasMetalBuffer.contents()), 1)
        }

        if self.xnsMetalBuffer == nil {
            let count = self.x_ns!.count
            let byteCount = count * sizeof(Int32)
            let options = MTLResourceOptions.StorageModeShared.union(.CPUCacheModeWriteCombined)
            self.xnsMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: options)
        }

        if let x_ns = self.x_ns, xnsMetalBuffer = self.xnsMetalBuffer {
            let count = x_ns.count
            let mutablePointer = UnsafeMutablePointer<Int32>(xnsMetalBuffer.contents())
            let buffer = UnsafeMutableBufferPointer<Int32>(start: mutablePointer, count: count)
            for index in buffer.startIndex ..< buffer.endIndex {
                buffer[index] = Int32(x_ns[index])
            }
        }

        if self.imageAmplitudesMetalBuffer == nil {
            let count = self.numberOfPixels
            let byteCount = count * sizeof(Float)
            let options = MTLResourceOptions.StorageModeShared.union(.CPUCacheModeDefaultCache)
            self.imageAmplitudesMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: options)
        }

        if self.imageIntensitiesMetalBuffer == nil {
            let count = self.numberOfPixels
            let byteCount = count * sizeof(UInt8)
            let options = MTLResourceOptions.StorageModeShared.union(.CPUCacheModeDefaultCache)
            self.imageIntensitiesMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: options)
        }

        self.isInitializationComplete = true
    }

    private func processChannelData(channelData: ChannelData?, withCommandBuffer metalCommandBuffer: MTLCommandBuffer)
    {
        if let channelData = channelData,
            channelDataMetalBuffers = self.channelDataMetalBuffers,
            imageAmplitudesMetalBuffer = self.imageAmplitudesMetalBuffer,
            channelDataParametersMetalBuffer = self.channelDataParametersMetalBuffer {
            let parameters = BeamformerParameters(numberOfChannels: Int32(channelData.numberOfChannels), numberOfSamplesPerChannel: Int32(channelData.numberOfSamplesPerChannel), pixelCount: Int32(self.numberOfPixels))
            UnsafeMutablePointer<BeamformerParameters>(channelDataParametersMetalBuffer.contents()).memory = parameters

            let channelDataMetalBuffer = channelDataMetalBuffers[self.computeFrameCycle]
            let channelDataMetalBufferPointer = channelDataMetalBuffer.contents()

            let length = channelData.complexSamples.count * sizeof(UInt16)
            memcpy(channelDataMetalBufferPointer, channelData.complexSamples, length)
            let commandEncoder = metalCommandBuffer.computeCommandEncoder()

            if let pipelineState = self.metalChannelDataPipelineState {
                commandEncoder.pushDebugGroup("Channel Processing")
                commandEncoder.setComputePipelineState(pipelineState)

                commandEncoder.setBuffer(self.channelDataParametersMetalBuffer, offset: 0, atIndex: 0)
                commandEncoder.setBuffer(channelDataMetalBuffer, offset: 0, atIndex: 1)
                commandEncoder.setBuffer(self.partAsMetalBuffer, offset: 0, atIndex: 2)
                commandEncoder.setBuffer(self.alphasMetalBuffer, offset: 0, atIndex: 3)
                commandEncoder.setBuffer(self.xnsMetalBuffer, offset: 0, atIndex: 4)
                commandEncoder.setBuffer(self.imageAmplitudesMetalBuffer, offset: 0, atIndex: 5)

                let maxPixelCount = imageAmplitudesMetalBuffer.length / sizeof(Float)
                let threadExecutionWidth = pipelineState.maxTotalThreadsPerThreadgroup
                let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
                let threadGroups = MTLSize(width: maxPixelCount / threadsPerThreadgroup.width, height: 1, depth:1)

                commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadgroup)
                commandEncoder.endEncoding()
                commandEncoder.popDebugGroup()
            }

            self.computeFrameCycle = (self.computeFrameCycle + 1) % kInflightCommandBuffers
        }
    }

    private func processDecibelValues(metalCommandBuffer: MTLCommandBuffer)
    {
        if let imageAmplitudesParametersMetalBuffer = self.imageAmplitudesParametersMetalBuffer, imageAmplitudesMetalBuffer = self.imageAmplitudesMetalBuffer {
//            let pixelCount = self.numberOfPixels
//            let imageAmplitudeBufferContents = UnsafePointer<Float>(imageAmplitudesMetalBuffer.contents())
//            let amplitudesMutablePointer = UnsafeMutablePointer<Float>(self.amplitudeValues)
//            cblas_scopy(Int32(pixelCount), imageAmplitudeBufferContents, 1, amplitudesMutablePointer, 1)

            let minimum: Float? = 0 //self.amplitudeValues.minElement()
            let maximum: Float? = 100 //self.amplitudeValues.maxElement()
            if let minimum = minimum, maximum = maximum {
                let parameters = ImageAmplitudesParameters(minimumValue: Float(minimum), maximumValue: Float(maximum))
                UnsafeMutablePointer<ImageAmplitudesParameters>(imageAmplitudesParametersMetalBuffer.contents()).memory = parameters
                let commandEncoder = metalCommandBuffer.computeCommandEncoder()

                if let pipelineState = self.metalDecibelValuePipelineState {
                    commandEncoder.pushDebugGroup("Decibel Values")
                    commandEncoder.setComputePipelineState(pipelineState)

                    commandEncoder.setBuffer(self.imageAmplitudesParametersMetalBuffer, offset: 0, atIndex: 0)
                    commandEncoder.setBuffer(self.imageAmplitudesMetalBuffer, offset: 0, atIndex: 1)
                    commandEncoder.setBuffer(self.imageIntensitiesMetalBuffer, offset: 0, atIndex: 2)

                    let maxPixelCount = imageAmplitudesMetalBuffer.length / sizeof(Float)
                    let threadExecutionWidth = pipelineState.maxTotalThreadsPerThreadgroup
                    let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
                    let threadGroups = MTLSize(width: maxPixelCount / threadsPerThreadgroup.width, height: 1, depth:1)

                    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadgroup)
                    commandEncoder.endEncoding()
                    commandEncoder.popDebugGroup()
                }
            }
        }
    }
}