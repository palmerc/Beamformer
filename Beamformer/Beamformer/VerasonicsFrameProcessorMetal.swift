import Foundation
import UIKit
import Metal
import Accelerate



public class VerasonicsFrameProcessorMetal: VerasonicsFrameProcessorBase
{
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

    private var region: MTLRegion!
    private var textureA: MTLTexture!
    private var textureB: MTLTexture!

    override init()
    {
        super.init()

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
//            let complexObject = channelData![index].complexSamples.zip
//            self.channelDataBufferPointer![index] = complexObject!
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
}