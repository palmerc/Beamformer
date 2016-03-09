import Foundation
import UIKit
import Metal
import Accelerate

struct ImageAmplitudesParameters {
    var minimumValue: Float
    var maximumValue: Float
}

struct BeamformerParameters {
    var channelCount: Int32
    var samplesPerChannel: Int32
    var pixelCount: Int32
}


public class VerasonicsFrameProcessorMetal: VerasonicsFrameProcessorBase
{
    private var isInitializationComplete = false
    private var channelDataParametersMetalBuffer: MTLBuffer?
    private var imageAmplitudesParametersMetalBuffer: MTLBuffer?

    private var channelDataPointer: UnsafeMutablePointer<Void> = nil
    private var channelDataBufferPointer: UnsafeMutableBufferPointer<ComplexNumber>?
    private var channelDataMetalBuffer: MTLBuffer?

    private var partAsPointer: UnsafeMutablePointer<Void> = nil
    private var partAsBufferPointer: UnsafeMutableBufferPointer<ComplexNumber>?
    private var partAsMetalBuffer: MTLBuffer?

    private var alphasPointer: UnsafeMutablePointer<Void> = nil
    private var alphasBufferPointer: UnsafeMutableBufferPointer<Float>?
    private var alphasMetalBuffer: MTLBuffer?

    private var xnsPointer: UnsafeMutablePointer<Void> = nil
    private var xnsBufferPointer: UnsafeMutableBufferPointer<Int32>?
    private var xnsMetalBuffer: MTLBuffer?

    private var imageAmplitudesMetalBuffer: MTLBuffer?
    private var imageIntensitiesMetalBuffer: MTLBuffer?

    // F***ing Metal
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

    private var queue: dispatch_queue_t!
    private let queueName = "no.uio.Beamformer"



    // MARK: Object lifecycle
    override init()
    {
        super.init()

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

    private func setupSharedMemoryWithSize(byteCount: Int) ->
        (pointer: UnsafeMutablePointer<Void>,
        memoryWrapper: COpaquePointer,
        size: Int)
    {
        let memoryAlignment = 0x1000
        var memory: UnsafeMutablePointer<Void> = nil

        let alignedByteCount = byteSizeWithAlignment(memoryAlignment, size: byteCount)
        posix_memalign(&memory, memoryAlignment, alignedByteCount)

        let memoryWrapper = COpaquePointer(memory)

        return (memory, memoryWrapper, alignedByteCount)
    }

    private func byteSizeWithAlignment(alignment: Int, size: Int) -> Int
    {
        return Int(ceil(Float(size) / Float(alignment))) * alignment
    }


    // MARK:

    public func complexVectorFromChannelData(channelData: ChannelData?) -> [UInt8]?
    {
        var imageVector: [UInt8]?
        if let channelData = channelData {
            if !self.isInitializationComplete {
                initializeBuffersWithSampleCount(channelData.complexSamples.count)
            }

//            let channelTime = self.executionTimeInterval({
            self.processChannelData(channelData)
            self.processDecibelValues()
//            })
//            print("Channel processing completed: \(channelTime) seconds")

            let pixelCount = self.numberOfPixels
            let byteCount = pixelCount * sizeof(UInt8)
            var pixelValues = [UInt8](count: pixelCount, repeatedValue: 0)

            let data = NSData(bytesNoCopy: self.imageIntensitiesMetalBuffer!.contents(), length: byteCount, freeWhenDone: false)
            data.getBytes(&pixelValues, length:byteCount)

            imageVector = pixelValues
        }

        return imageVector
    }

    private func initializeBuffersWithSampleCount(sampleCount: Int)
    {
        if self.imageAmplitudesParametersMetalBuffer == nil {
            let byteCount = sizeof(ImageAmplitudesParameters)
            self.imageAmplitudesParametersMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: .StorageModeShared)
        }
        if self.channelDataParametersMetalBuffer == nil {
            let byteCount = sizeof(BeamformerParameters)
            self.channelDataParametersMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: .StorageModeShared)
        }

        if self.channelDataPointer == nil {
            let byteCount = sampleCount * sizeof(ComplexNumber)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.channelDataMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: .StorageModeShared, deallocator: nil)
            self.channelDataPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<ComplexNumber>(memoryWrapper)
            self.channelDataBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: sampleCount)
        }

        if self.partAsPointer == nil {
            let count = self.partAs!.count
            let byteCount = count * sizeof(ComplexNumber)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.partAsMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: .StorageModeShared, deallocator: nil)
            self.partAsPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<ComplexNumber>(memoryWrapper)
            self.partAsBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: count)
        }

        if let partAs = self.partAs, partAsBufferPointer = self.partAsBufferPointer {
            for index in partAsBufferPointer.startIndex ..< partAsBufferPointer.endIndex {
                partAsBufferPointer[index] = partAs[index]
            }
        }

        if self.alphasPointer == nil {
            let count = self.alphas!.count
            let byteCount = count * sizeof(Float)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.alphasMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: .StorageModeShared, deallocator: nil)
            self.alphasPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<Float>(memoryWrapper)
            self.alphasBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: count)
        }

        if let alphas = self.alphas, alphasBufferPointer = self.alphasBufferPointer {
            for index in alphasBufferPointer.startIndex ..< alphasBufferPointer.endIndex {
                alphasBufferPointer[index] = alphas[index]
            }
        }

        if self.xnsPointer == nil {
            let count = self.x_ns!.count
            let byteCount = count * sizeof(Int32)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.xnsMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: .StorageModeShared, deallocator: nil)
            self.xnsPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<Int32>(memoryWrapper)
            self.xnsBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: count)
        }

        if let x_ns = self.x_ns, xnsBufferPointer = self.xnsBufferPointer {
            for index in xnsBufferPointer.startIndex ..< xnsBufferPointer.endIndex {
                xnsBufferPointer[index] = Int32(x_ns[index])
            }
        }

        if self.imageAmplitudesMetalBuffer == nil {
            let count = self.numberOfPixels
            let byteCount = count * sizeof(Float)

            self.imageAmplitudesMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: .StorageModeShared)
        }

        if self.imageIntensitiesMetalBuffer == nil {
            let count = self.numberOfPixels
            let byteCount = count * sizeof(UInt8)

            self.imageIntensitiesMetalBuffer = self.metalDevice.newBufferWithLength(byteCount, options: .StorageModeShared)
        }

        self.isInitializationComplete = true
    }

    private func processChannelData(channelData: ChannelData?)
    {
        if let channelData = channelData, channelDataBufferPointer = self.channelDataBufferPointer, channelDataParametersMetalBuffer = self.channelDataParametersMetalBuffer {
            let parameters = BeamformerParameters(channelCount: Int32(self.numberOfActiveTransducerElements), samplesPerChannel: Int32(channelData.samplesPerChannel), pixelCount: Int32(self.numberOfPixels))
            UnsafeMutablePointer<BeamformerParameters>(channelDataParametersMetalBuffer.contents()).memory = parameters

            for index in channelDataBufferPointer.startIndex ..< channelDataBufferPointer.endIndex {
                let sample = channelData.complexSamples[index]
                channelDataBufferPointer[index] = sample
            }

            let metalCommandBuffer = self.metalCommandQueue.commandBuffer()
            let commandEncoder = metalCommandBuffer.computeCommandEncoder()

            if let pipelineState = self.metalChannelDataPipelineState {
                commandEncoder.setComputePipelineState(pipelineState)

                commandEncoder.setBuffer(self.channelDataParametersMetalBuffer, offset: 0, atIndex: 0)
                commandEncoder.setBuffer(self.channelDataMetalBuffer, offset: 0, atIndex: 1)
                commandEncoder.setBuffer(self.partAsMetalBuffer, offset: 0, atIndex: 2)
                commandEncoder.setBuffer(self.alphasMetalBuffer, offset: 0, atIndex: 3)
                commandEncoder.setBuffer(self.xnsMetalBuffer, offset: 0, atIndex: 4)
                commandEncoder.setBuffer(self.imageAmplitudesMetalBuffer, offset: 0, atIndex: 5)

                let threadExecutionWidth = pipelineState.threadExecutionWidth
                let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
                let threadGroups = MTLSize(width: self.numberOfPixels / threadsPerThreadgroup.width, height: 1, depth:1)

                commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadgroup)
                commandEncoder.endEncoding()
                metalCommandBuffer.commit()
                metalCommandBuffer.waitUntilCompleted()
            }
        }
    }

    private func processDecibelValues()
    {
        if let imageAmplitudesParametersMetalBuffer = self.imageAmplitudesParametersMetalBuffer, imageAmplitudesMetalBuffer = self.imageAmplitudesMetalBuffer {
            let pixelCount = self.numberOfPixels
            let byteCount = pixelCount * sizeof(Float)
            var pixelValues = [Float](count: pixelCount, repeatedValue: 0)

            let data = NSData(bytesNoCopy: imageAmplitudesMetalBuffer.contents(), length: byteCount, freeWhenDone: false)
            data.getBytes(&pixelValues, length:byteCount)

//            let decibels = pixelValues.map({ (value: Float) -> String in
//                return "\(value)"
//            })
//            let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
//            var docs: String = paths[0] as! String
//            let dir = NSURL(string: docs)
//            let decibelFile = dir?.URLByAppendingPathComponent("decibels.txt")
//
//            let val = decibels.joinWithSeparator(",")
//            do {
//                try val.writeToFile(decibelFile!.absoluteString, atomically: true, encoding: NSUTF8StringEncoding)
//            } catch {}

            let minimum = pixelValues.minElement()
            let maximum = pixelValues.maxElement()
            if let minimum = minimum, maximum = maximum {
                let parameters = ImageAmplitudesParameters(minimumValue: Float(minimum), maximumValue: Float(maximum))
                UnsafeMutablePointer<ImageAmplitudesParameters>(imageAmplitudesParametersMetalBuffer.contents()).memory = parameters
                let metalCommandBuffer = self.metalCommandQueue.commandBuffer()
                let commandEncoder = metalCommandBuffer.computeCommandEncoder()

                if let pipelineState = self.metalDecibelValuePipelineState {
                    commandEncoder.setComputePipelineState(pipelineState)

                    commandEncoder.setBuffer(self.imageAmplitudesParametersMetalBuffer, offset: 0, atIndex: 0)
                    commandEncoder.setBuffer(self.imageAmplitudesMetalBuffer, offset: 0, atIndex: 1)
                    commandEncoder.setBuffer(self.imageIntensitiesMetalBuffer, offset: 0, atIndex: 2)

                    let threadExecutionWidth = pipelineState.threadExecutionWidth
                    let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
                    let threadGroups = MTLSize(width: self.numberOfPixels / threadsPerThreadgroup.width, height: 1, depth:1)

                    commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadgroup)
                    commandEncoder.endEncoding()
                    metalCommandBuffer.commit()
                    metalCommandBuffer.waitUntilCompleted()
                }
            }
        }
    }

    func executionTimeInterval(block: () -> ()) -> CFTimeInterval
    {
        let start = CACurrentMediaTime()
        block();
        let end = CACurrentMediaTime()
        return end - start
    }
}