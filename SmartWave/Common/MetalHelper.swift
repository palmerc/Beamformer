import Foundation
import Metal



public class MetalHelper {
    public static func setup(with device: MTLDevice?) -> (metalDevice: MTLDevice?,
        metalLibrary: MTLLibrary?,
        metalCommandQueue: MTLCommandQueue?)
    {
        var metalDevice = device
        if metalDevice == nil {
            metalDevice = MTLCreateSystemDefaultDevice()
        }
        let metalLibrary = device?.newDefaultLibrary()
        let metalCommandQueue = device?.makeCommandQueue()

        return (metalDevice, metalLibrary, metalCommandQueue)
    }

    static func setupPipeline(kernelFunctionName: String, metalDevice: MTLDevice?, metalLibrary: MTLLibrary?) ->
        (metalKernelFunction: MTLFunction?,
        metalPipelineState: MTLComputePipelineState?)
    {
        let metalKernelFunction: MTLFunction? = metalLibrary?.makeFunction(name: kernelFunctionName)

        let computePipeLineDescriptor = MTLComputePipelineDescriptor()
        computePipeLineDescriptor.computeFunction = metalKernelFunction
        computePipeLineDescriptor.label = kernelFunctionName

        var metalPipelineState: MTLComputePipelineState? = nil
        do {
            metalPipelineState = try metalDevice?.makeComputePipelineState(function: metalKernelFunction!)
        } catch let error as NSError {
            print("Compute pipeline state acquisition failed. \(error.localizedDescription)")
        }

        return (metalKernelFunction, metalPipelineState)
    }
}
