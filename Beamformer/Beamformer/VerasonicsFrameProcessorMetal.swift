import Foundation
import UIKit
import Metal
import Accelerate

struct ChannelDataParameters {
    var numberOfChannelDataSamples: Int
    var numberOfPixels: Int
}



public class VerasonicsFrameProcessorMetal: VerasonicsFrameProcessorBase
{
    private var channelDataParametersPointer: UnsafeMutablePointer<Void> = nil
    private var channelDataParametersMetalBuffer: MTLBuffer?

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
    private var xnsBufferPointer: UnsafeMutableBufferPointer<Int>?
    private var xnsMetalBuffer: MTLBuffer?

    private var ultrasoundBitmapPointer: UnsafeMutablePointer<Void> = nil
    private var ultrasoundBitmapBufferPointer: UnsafeMutableBufferPointer<ComplexNumber>?
    private var ultrasoundBitmapMetalBuffer: MTLBuffer?

    // F***ing Metal
    private var metalDevice: MTLDevice! = nil
    private var metalDefaultLibrary: MTLLibrary! = nil
    private var metalCommandQueue: MTLCommandQueue! = nil
    private var metalKernelFunction: MTLFunction!
    private var metalPipelineState: MTLComputePipelineState!
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
        if metalDevice != nil {
            let (metalKernelFunction, metalPipelineState) = self.setupShaderInMetalPipelineWithName("processChannelData", withDevice: metalDevice, inLibrary: metalLibrary)

            self.metalDevice = metalDevice
            self.metalKernelFunction = metalKernelFunction
            self.metalPipelineState = metalPipelineState
            self.metalDefaultLibrary = metalLibrary
            self.metalCommandQueue = metalCommandQueue

            self.queue = dispatch_queue_create(queueName, DISPATCH_QUEUE_CONCURRENT)
        } else {
            print("Failed to find a Metal device. Processing will be performed on CPU.")
        }
    }

    deinit
    {
        if self.channelDataPointer != nil {
            self.channelDataPointer.destroy()
        }
        if self.ultrasoundBitmapPointer != nil {
            self.ultrasoundBitmapPointer.destroy()
        }
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

    public func complexVectorFromChannelData(channelData: ChannelData?) -> [ComplexNumber]?
    {
        if self.channelDataParametersPointer == nil {
            let byteCount = sizeof(ChannelDataParameters)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.channelDataParametersPointer = memory
            self.channelDataParametersMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: MTLResourceOptions(rawValue: 0), deallocator: nil)

            let typedOpaquePointer = UnsafeMutablePointer<ChannelDataParameters>(memoryWrapper)
            typedOpaquePointer.memory.numberOfPixels = self.numberOfPixels
            typedOpaquePointer.memory.numberOfChannelDataSamples = channelData!.complexSamples.count
        }

        if self.channelDataPointer == nil {
            let samplesCount = channelData!.complexSamples.count
            let byteCount = samplesCount * sizeof(ComplexNumber)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.channelDataMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: MTLResourceOptions(rawValue: 0), deallocator: nil)
            self.channelDataPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<ComplexNumber>(memoryWrapper)
            self.channelDataBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: samplesCount)
        }

        for index in self.channelDataBufferPointer!.startIndex ..< self.channelDataBufferPointer!.endIndex {
            let sample = channelData!.complexSamples[index]
            self.channelDataBufferPointer![index] = sample
        }

        if self.partAsPointer == nil {
            let count = self.partAs!.count
            let byteCount = count * sizeof(ComplexNumber)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.partAsMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: MTLResourceOptions(rawValue: 0), deallocator: nil)
            self.partAsPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<ComplexNumber>(memoryWrapper)
            self.partAsBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: count)
        }

        for index in self.partAsBufferPointer!.startIndex ..< self.partAsBufferPointer!.endIndex {
            let partA = self.partAs![index]
            self.partAsBufferPointer![index] = partA
        }

        if self.alphasPointer == nil {
            let count = self.alphas!.count
            let byteCount = count * sizeof(Float)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.alphasMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: MTLResourceOptions(rawValue: 0), deallocator: nil)
            self.alphasPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<Float>(memoryWrapper)
            self.alphasBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: count)
        }

        for index in self.alphasBufferPointer!.startIndex ..< self.alphasBufferPointer!.endIndex {
            let alpha = self.alphas![index]
            self.alphasBufferPointer![index] = alpha
        }

        if self.xnsPointer == nil {
            let count = self.x_ns!.count
            let byteCount = count * sizeof(Int)
            let (memory, memoryWrapper, size) = setupSharedMemoryWithSize(byteCount)
            self.xnsMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: MTLResourceOptions(rawValue: 0), deallocator: nil)
            self.xnsPointer = memory
            let typedOpaquePointer = UnsafeMutablePointer<Int>(memoryWrapper)
            self.xnsBufferPointer = UnsafeMutableBufferPointer(start: typedOpaquePointer, count: count)
        }

        for index in self.xnsBufferPointer!.startIndex ..< self.xnsBufferPointer!.endIndex {
            let xn = self.x_ns![index]
            self.xnsBufferPointer![index] = xn
        }

        let complexPixelCount = self.numberOfActiveTransducerElements * self.numberOfPixels
        let complexByteCount = complexPixelCount * sizeof(ComplexNumber)
        if self.ultrasoundBitmapPointer == nil {
            let (memory, _, size) = setupSharedMemoryWithSize(complexByteCount)
            self.ultrasoundBitmapMetalBuffer = self.metalDevice.newBufferWithBytesNoCopy(memory, length: size, options: MTLResourceOptions(rawValue: 0), deallocator: nil)
            self.ultrasoundBitmapPointer = memory
        }

        let copiedPixelValues = [ComplexNumber](count: complexPixelCount, repeatedValue: ComplexNumber(real: 0, imaginary: 0))
        let copiedPixelValuesPtr = UnsafeMutablePointer<ComplexNumberF>(copiedPixelValues)

        let samplesPtr = UnsafePointer<ComplexNumberF>(channelData!.complexSamples)
        let partAsPtr = UnsafePointer<ComplexNumberF>(self.partAs!)
        let alphasPtr = UnsafePointer<Float>(self.alphas!)
        let xnsPtr = UnsafePointer<Int>(self.x_ns!)

        let time = self.executionTimeInterval({
            processChannelData(samplesPtr, partAsPtr, alphasPtr, xnsPtr, copiedPixelValuesPtr)
        })
        print("executed in \(time) seconds")
//        processChannelDataWithMetal()

//        let data = NSData(bytesNoCopy: self.ultrasoundBitmapMetalBuffer!.contents(), length: complexByteCount)
//        data.getBytes(&copiedPixelValues, length:complexByteCount)

        let imageVector = imageVectorFromComplexVector(copiedPixelValues)

        return imageVector
    }

    private func processChannelDataWithMetal()
    {
        let metalCommandBuffer = self.metalCommandQueue.commandBuffer()
        let commandEncoder = metalCommandBuffer.computeCommandEncoder()

        if metalPipelineState != nil {
            commandEncoder.setComputePipelineState(metalPipelineState!)
        }

        commandEncoder.setBuffer(self.channelDataParametersMetalBuffer, offset: 0, atIndex: 0)
        commandEncoder.setBuffer(self.channelDataMetalBuffer, offset: 0, atIndex: 1)
        commandEncoder.setBuffer(self.partAsMetalBuffer, offset: 0, atIndex: 2)
        commandEncoder.setBuffer(self.alphasMetalBuffer, offset: 0, atIndex: 3)
        commandEncoder.setBuffer(self.xnsMetalBuffer, offset: 0, atIndex: 4)
        commandEncoder.setBuffer(self.ultrasoundBitmapMetalBuffer, offset: 0, atIndex: 5)

//        let threadExecutionWidth = metalPipelineState!.threadExecutionWidth
        let threadGroups = MTLSize(width: 1, height: 1, depth:1)
        let threadGroupCount = MTLSize(width: 1, height: 1, depth: 1)

        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupCount)
        commandEncoder.endEncoding()
        metalCommandBuffer.commit()
        metalCommandBuffer.waitUntilCompleted()
    }

    func imageVectorFromComplexVector(complexVector: [ComplexNumber]) -> [ComplexNumber]
    {
        var imageVectorReals = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var imageVectorImaginaries = [Float](count: self.numberOfPixels, repeatedValue: 0)
        var imageVectorWrapper = DSPSplitComplex(realp: &imageVectorReals, imagp: &imageVectorImaginaries)

        let splitVector = ComplexVector(complexNumbers: complexVector)
        let splitVectorReals = splitVector.reals!
        let splitVectorImaginaries = splitVector.imaginaries!
        dispatch_apply(self.numberOfActiveTransducerElements, self.queue) {
            (channelIdentifier: Int) -> Void in
            let startIndex = channelIdentifier * self.numberOfPixels
            let endIndex = startIndex + self.numberOfPixels
            var splitVectorRealsSlice = Array(splitVectorReals[startIndex ..< endIndex])
            var splitVectorImaginariesSlice = Array(splitVectorImaginaries[startIndex ..< endIndex])
            var splitVectorWrapper = DSPSplitComplex(realp: &splitVectorRealsSlice, imagp: &splitVectorImaginariesSlice)
            objc_sync_enter(self)
            vDSP_zvadd(&splitVectorWrapper, 1, &imageVectorWrapper, 1, &imageVectorWrapper, 1, UInt(self.numberOfPixels))
            objc_sync_exit(self)
        }

        return ComplexVector(reals: imageVectorReals, imaginaries: imageVectorImaginaries).complexNumbers!
    }

    func executionTimeInterval(block: () -> ()) -> CFTimeInterval
    {
        let start = CACurrentMediaTime()
        block();
        let end = CACurrentMediaTime()
        return end - start
    }
}