import Foundation
import Metal
import MetalKit
import Accelerate

struct ProbeParameters {
    var numberOfAngles: Int32
    var numberOfChannels: Int32
    var numberOfSamplesPerChannel: Int32
    var samplingFrequencyHz: Float
    var centralFrequencyHz: Float
    var lensCorrection: Float
    var elementPitchMillimeters: Float
}

struct ProcessingParameters {
    var speedOfSoundInMillimetersPerSecond: Float
    var fNumber: Float
    var imageStartXInMillimeters: Float
    var imageStartZInMillimeters: Float
    var gain: Float
    var dynamicRange: Float
}

private let kInflightCommandBuffers = 5

open class VerasonicsFrameProcessorMetal: NSObject, MTKViewDelegate
{
    private var startDrawTime: CFTimeInterval = 0
    private var currentDrawTime: CFTimeInterval = 0
    
    var delegate: UltrasoundViewControllerMobile?
    private var metalView: MTKView?
    private var metalDevice: MTLDevice?
    private var metalLibrary: MTLLibrary?
    private var metalCommandQueue: MTLCommandQueue?
    
    private var channelDataPipelineState: MTLComputePipelineState?
    private var renderPipelineState: MTLRenderPipelineState?
    
    private let internalVerasonicsFramesAccessQueue = DispatchQueue(label:"FramesLockingQueue")
    private var internalVerasonicsFrames = [Smartwave_Frame]()
    private var verasonicsFrames: [Smartwave_Frame] {
        get {
            return internalVerasonicsFramesAccessQueue.sync {
                internalVerasonicsFrames
            }
        }
        
        set(newVerasonicsFrames) {
            internalVerasonicsFramesAccessQueue.sync {
                internalVerasonicsFrames = newVerasonicsFrames
            }
        }
    }
    
    var speedOfSoundInMillimetersPerSecond: Float = 0
    var _imageRangeXInMillimeters = ValueRange(lowerBound: 0, upperBound: 0)
    var imageRangeXInMillimeters: ValueRange {
        get {
            return _imageRangeXInMillimeters
        }
        set {
            _imageRangeXInMillimeters = newValue
            
            resetResources()
        }
    }
    var _imageRangeZInMillimeters = ValueRange(lowerBound: 0, upperBound: 0)
    var imageRangeZInMillimeters: ValueRange {
        get {
            return _imageRangeZInMillimeters
        }
        set {
            _imageRangeZInMillimeters = newValue
            
            resetResources()
        }
    }
    
    private let gainLock = DispatchQueue(label:"GainLockingQueue")
    private var _gainValue: Float?
    var gain: Float? {
        get {
            return gainLock.sync {
               _gainValue
            }
        }
        
        set {
            gainLock.sync {
                guard let gainValue = newValue,
                    gainValue != _gainValue else {
                        return
                }
                
                _gainValue = gainValue
            }
        }
    }
    
    private let dynamicRangeLock = DispatchQueue(label:"DynamicRangeLockingQueue")
    private var _dynamicRangeValue: Float?
    var dynamicRange: Float? {
        get {
            return dynamicRangeLock.sync {
                _dynamicRangeValue
            }
        }
        
        set {
            dynamicRangeLock.sync {
                guard let dynamicRangeValue = newValue,
                    dynamicRangeValue != _dynamicRangeValue else {
                        return
                }
                
                _dynamicRangeValue = dynamicRangeValue
            }
        }
    }
    
    var fNumber: Float = 0
    var numberOfPixels: Int = 0
    
    private var settingsIdentifier = "Undefined"
    private var updateProbeParameters: Bool = false
    private var probeParameters: ProbeParameters?
    private var processingParameters: ProcessingParameters?
    private var anglesInRadians: [Float]?
    
    private let internalVerasonicsSettingsAccessQueue = DispatchQueue(label:"SettingsLockingQueue")
    private var internalVerasonicsSettings: Smartwave_Settings?
    private var verasonicsSettings: Smartwave_Settings? {
        get {
            return internalVerasonicsSettingsAccessQueue.sync {
                internalVerasonicsSettings
            }
        }
        
        set(newProbeParameters) {
            internalVerasonicsSettingsAccessQueue.sync {
                internalVerasonicsSettings = newProbeParameters
                guard let identifier = internalVerasonicsSettings?.identifier,
                    let numberOfChannels = internalVerasonicsSettings?.channelCount,
                    let numberOfSamplesPerChannel = internalVerasonicsSettings?.samplesPerChannel,
                    let samplingFrequencyHz = internalVerasonicsSettings?.samplingFrequencyHz,
                    let centralFrequencyHz = internalVerasonicsSettings?.centralFrequencyHz,
                    let lensCorrection = internalVerasonicsSettings?.lensCorrection,
                    let elementPitchMillimeters = internalVerasonicsSettings?.elementPitchMillimeters,
                    let anglesInRadians = internalVerasonicsSettings?.anglesInRadians else {
                        print("Unable to set new probe parameters.");
                        return
                }
                
                let numberOfAngles = Int32(anglesInRadians.count)
                let anglesInRadiansFloat = anglesInRadians.map{ Float($0) }
                self.anglesInRadians = anglesInRadiansFloat
                
                let probeParameters = ProbeParameters(numberOfAngles: numberOfAngles,
                                                      numberOfChannels: numberOfChannels,
                                                      numberOfSamplesPerChannel: numberOfSamplesPerChannel,
                                                      samplingFrequencyHz: Float(samplingFrequencyHz),
                                                      centralFrequencyHz: Float(centralFrequencyHz),
                                                      lensCorrection: Float(lensCorrection),
                                                      elementPitchMillimeters: Float(elementPitchMillimeters))
                self.probeParameters = probeParameters
                self.settingsIdentifier = identifier
                
                resetResources()
            }
        }
    }
    
    private var probeParametersMetalBuffer: MTLBuffer?
    private var processingParametersMetalBuffer: MTLBuffer?
    private var anglesInRadiansMetalBuffer: MTLBuffer?
    private var channelDataMetalBuffers: [MTLBuffer]?
    private var vertexBuffers: [MTLBuffer]?
    private var textures: [MTLTexture]?
    
    private var totalDrawCallCount: Int
    private var currentCommandBuffer: Int
    private var inflightSemaphore: DispatchSemaphore?
    
    override init()
    {
        self.currentCommandBuffer = 0
        self.totalDrawCallCount = 0
        
        super.init()
    }
    
    // MARK: Object lifecycle
    convenience init(with view: MTKView)
    {
        self.init()
        
        view.delegate = self
        
        let (metalDevice, metalLibrary, metalCommandQueue) = MetalHelper.setup(with: view.device)
        self.metalView = view
        self.metalDevice = metalDevice
        self.metalLibrary = metalLibrary
        self.metalCommandQueue = metalCommandQueue

        buildRenderResources()
        buildRenderPipeline()
        buildComputeResources()
        buildComputePipelines()
    }
    
    deinit
    {
    }
    
    func updateSettings(_ settings: Smartwave_Settings?)
    {
        self.verasonicsSettings = settings
    }
    
    func enqueFrame(_ frame: Smartwave_Frame?)
    {
        //, self.verasonicsFrames.count < kInflightCommandBuffers
        if let frame = frame {
            self.verasonicsFrames.append(frame)
        }
        
        print("Buffer size \(self.verasonicsFrames.count)")
    }
    
    fileprivate func resetResources()
    {
        self.inflightSemaphore = nil
        
        self.verasonicsFrames.removeAll(keepingCapacity: true)

        buildComputeResources()
        
        guard let probeParameters = self.probeParameters,
            let probeParametersMetalBuffer = self.probeParametersMetalBuffer else {
            return
        }
        
        let probeContents = probeParametersMetalBuffer.contents().bindMemory(to: ProbeParameters.self, capacity: 1)
        probeContents.pointee = probeParameters
        
        guard let anglesInRadians = self.anglesInRadians,
            let anglesInRadiansMetalBuffer = self.anglesInRadiansMetalBuffer else {
            return
        }
        
        let anglesInRadiansMutablePointer = anglesInRadiansMetalBuffer.contents().assumingMemoryBound(to: Float.self)
        anglesInRadians.withUnsafeBufferPointer({
            (buffer: UnsafeBufferPointer<Float>) in
            for i in stride(from: buffer.startIndex, to: buffer.endIndex, by: 1) {
                anglesInRadiansMutablePointer[i] = buffer[i]
            }
        })
        
        self.inflightSemaphore = DispatchSemaphore(value: kInflightCommandBuffers)
    }
    
    fileprivate func buildRenderResources()
    {
        // Vertex data for a full-screen quad. The first two numbers in each row represent
        // the x, y position of the point in normalized coordinates. The second two numbers
        // represent the texture coordinates for the corresponding position.
        let vertexData = [Float](arrayLiteral:
            -1,  1, 0, 0,
                 -1, -1, 0, 1,
                 1, -1, 1, 1,
                 1, -1, 1, 1,
                 1,  1, 1, 0,
                 -1,  1, 0, 0)
        
        var vertexBuffers = [MTLBuffer]()
        for index in 0 ..< kInflightCommandBuffers {
            let options = MTLResourceOptions().union(.storageModeShared)
            let byteCount = vertexData.count * MemoryLayout<Float>.size
            if let vertexBuffer = self.metalDevice?.makeBuffer(bytes: vertexData, length: byteCount, options: options) {
                vertexBuffer.label = "Vertex Buffer \(index)"
                vertexBuffers.append(vertexBuffer)
            }
        }
        
        if vertexBuffers.count > 0 {
            self.vertexBuffers = vertexBuffers
        }
    }
    
    fileprivate func buildRenderPipeline()
    {
        // Retrieve the functions we need to build the render pipeline
        let vertexProgram: MTLFunction? = self.metalLibrary?.makeFunction(name: "basicVertex")
        let fragmentProgram: MTLFunction? = self.metalLibrary?.makeFunction(name: "basicFragment")
        
        // Create a vertex descriptor that describes a vertex with two float2 members:
        // position and texture coordinates
        let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<float2>.size * 2
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.layouts[0].stride = MemoryLayout<float2>.size * 4
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        // Describe and create a render pipeline state
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "Fullscreen Quad Pipeline"
        pipelineStateDescriptor.vertexFunction = vertexProgram
        pipelineStateDescriptor.fragmentFunction = fragmentProgram
        pipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        if let pixelFormat = self.metalView?.colorPixelFormat {
            pipelineStateDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        }
        
        var renderPipelineState: MTLRenderPipelineState?
        do {
            renderPipelineState = try self.metalDevice?.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            print("Failed to create render pipeline state. \(error.localizedDescription)")
        }
        self.renderPipelineState = renderPipelineState
    }
    
    fileprivate func buildComputePipelines()
    {
        if let metalDevice = self.metalDevice,
            let metalLibrary = self.metalLibrary {
            let (_, channelDataPipelineState) = MetalHelper.setupPipeline(kernelFunctionName: "processChannelData", metalDevice: metalDevice, metalLibrary: metalLibrary)
            self.channelDataPipelineState = channelDataPipelineState
        }
    }
    
    fileprivate func buildComputeResources()
    {
        // Probe parameters
        guard let probeParameters = self.probeParameters else {
            print("Cannot setup compute resources without probe parameters.")
            return
        }
        
        let probeParametersByteCount = MemoryLayout<ProbeParameters>.size
        let probeParametersOptions = MTLResourceOptions().union(.cpuCacheModeWriteCombined)
        self.probeParametersMetalBuffer = self.metalDevice?.makeBuffer(length: probeParametersByteCount,
                                                                             options: probeParametersOptions)
        self.probeParametersMetalBuffer?.label = "Probe parameters"
        
        // Processing parameters
        let processingParametersByteCount = MemoryLayout<ProcessingParameters>.size
        let processingParametersOptions = MTLResourceOptions().union(.cpuCacheModeWriteCombined)
        self.processingParametersMetalBuffer = self.metalDevice?.makeBuffer(length: processingParametersByteCount, options: processingParametersOptions)
        self.processingParametersMetalBuffer?.label = "Processing parameters"
        
        // Angles in radians
        let numberOfAngles = Int(probeParameters.numberOfAngles)
        guard numberOfAngles > 0 else {
            print("Invalid number of angles in probe parameters")
            return
        }
        let anglesInRadiansByteCount = MemoryLayout<Float>.size * numberOfAngles
        let anglesInRadiansOptions = MTLResourceOptions().union(.cpuCacheModeWriteCombined)
        self.anglesInRadiansMetalBuffer = self.metalDevice?.makeBuffer(length: anglesInRadiansByteCount,
                                                                       options: anglesInRadiansOptions)
        self.anglesInRadiansMetalBuffer?.label = "Angles in radians"
        
        // Channel data buffers
        let numberOfChannels = Int(probeParameters.numberOfChannels)
        let samplesPerChannel = Int(probeParameters.numberOfSamplesPerChannel)
        let valuesPerSample = 2
        let bytesPerValue = MemoryLayout<Int32>.size
        var metalBuffers = [MTLBuffer]()
        for index in 0 ..< kInflightCommandBuffers {
            let byteCount = numberOfAngles * numberOfChannels * samplesPerChannel * valuesPerSample * bytesPerValue
            let options = MTLResourceOptions().union(.cpuCacheModeWriteCombined )
            let channelDataBuffer = self.metalDevice?.makeBuffer(length: byteCount, options: options)
            channelDataBuffer?.label = "Channel data buffer \(index)"
            
            if let channelDataMetalBuffer = channelDataBuffer {
                metalBuffers.append(channelDataMetalBuffer)
            }
        }
        
        if metalBuffers.count > 0 {
            self.channelDataMetalBuffers = metalBuffers
        }
        
        // Texture memory
        var textures = [MTLTexture]()
        let imageSize = self.imageSize
        for index in 0 ..< kInflightCommandBuffers {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Uint, width: imageSize.width, height: imageSize.height, mipmapped: false)
            textureDescriptor.usage = MTLTextureUsage.shaderRead.union(.shaderWrite)
            if let texture = self.metalDevice?.makeTexture(descriptor: textureDescriptor) {
                texture.label = "Texture \(index)"
                textures.append(texture)
            }
        }
        
        if textures.count > 0 {
            self.textures = textures
        }
        
        DispatchQueue.main.async {
            self.delegate?.didUpdateMetalViewSize(size: imageSize)
        }
    }
    
    // MARK:
    
    fileprivate func encodeComputeWork(in buffer: MTLCommandBuffer, frame: Smartwave_Frame)
    {
        guard let channelDataMetalBuffers = self.channelDataMetalBuffers else {
            print("channelDataMetalBuffers unavailable.")
            return
        }
            
        let channelDataMetalBuffer = channelDataMetalBuffers[self.currentCommandBuffer]
        
        let channelDataMutablePointer = channelDataMetalBuffer.contents().assumingMemoryBound(to: Int32.self)
        
        frame.channelSamples.withUnsafeBufferPointer({
            (buffer: UnsafeBufferPointer<Int32>) in
            for i in stride(from: buffer.startIndex, to: buffer.endIndex, by: 1) {
                channelDataMutablePointer[i] = buffer[i]
            }
        })

        let commandEncoder = buffer.makeComputeCommandEncoder()
        if let pipelineState = self.channelDataPipelineState,
            let currentTexture = self.textures?[self.currentCommandBuffer] {
            commandEncoder.pushDebugGroup("encodeComputeWork")
            commandEncoder.setComputePipelineState(pipelineState)
            
            commandEncoder.setTexture(currentTexture, at: 0)
            commandEncoder.setBuffer(self.probeParametersMetalBuffer, offset: 0, at: 0)
            commandEncoder.setBuffer(self.processingParametersMetalBuffer, offset: 0, at: 1)
            commandEncoder.setBuffer(self.anglesInRadiansMetalBuffer, offset: 0, at: 2)
            commandEncoder.setBuffer(channelDataMetalBuffer, offset: 0, at: 3)
            
            let threadsPerThreadgroup = MTLSize(width: pipelineState.maxTotalThreadsPerThreadgroup, height: 1, depth: 1)
            let threadGroups = MTLSize(width: self.numberOfPixels / threadsPerThreadgroup.width, height: 1, depth:1)
            
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerThreadgroup)
            commandEncoder.endEncoding()
            commandEncoder.popDebugGroup()
        }
    }
    
    fileprivate func encodeRenderWork(in buffer: MTLCommandBuffer)
    {
        if let renderPipelineState = self.renderPipelineState,
            let renderPassDescriptor = self.metalView?.currentRenderPassDescriptor,
            let currentDrawable = self.metalView?.currentDrawable,
            let currentTexture = self.textures?[self.currentCommandBuffer],
            let vertexBuffer = self.vertexBuffers?[self.currentCommandBuffer] {
            // Create a render command encoder, which we can use to encode draw calls into the buffer
            let renderEncoder = buffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            
            renderEncoder.pushDebugGroup("encodeRenderWork")
            
            // Configure the render encoder for drawing the full-screen quad, then issue the draw call
            renderEncoder.setRenderPipelineState(renderPipelineState)
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, at: 0)
            renderEncoder.setFragmentTexture(currentTexture, at: 0)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            renderEncoder.endEncoding()
            renderEncoder.popDebugGroup()
            
            // Present the texture we just rendered on the screen
            buffer.present(currentDrawable)
        }
    }
    
    // Called whenever view changes orientation or layout is changed
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {
        
    }
    
    // Called whenever the view needs to render
    public func draw(in view: MTKView)
    {
        if self.verasonicsFrames.count > 0,
            let _ = self.inflightSemaphore?.wait(timeout: .distantFuture) {
            self.currentCommandBuffer = (self.currentCommandBuffer + 1) % kInflightCommandBuffers
            
            updateProcessingParameters()
            if let commandBuffer = self.metalCommandQueue?.makeCommandBuffer() {
                guard !self.verasonicsFrames.isEmpty else {
                    print("No frames available.")
                    return
                }
                
                let verasonicsFrame = self.verasonicsFrames.removeFirst()
                guard verasonicsFrame.settingsIdentifier == self.settingsIdentifier else {
                    print("Skipping frame with invalid settings identifier, \(verasonicsFrame.settingsIdentifier) vs. \(self.settingsIdentifier)")
                    return
                }
                
                commandBuffer.addCompletedHandler({
                    (buffer: MTLCommandBuffer) in
                    self.inflightSemaphore?.signal()
                    
                    let elapsedTime = commandBuffer.gpuEndTime - commandBuffer.gpuStartTime
                    DispatchQueue.main.async {
                        self.delegate?.didCompleteCommandBuffer(elapsedTime: elapsedTime)
                    }
                })
                
                self.totalDrawCallCount = self.totalDrawCallCount + 1
                
                self.encodeComputeWork(in: commandBuffer, frame: verasonicsFrame)
                self.encodeRenderWork(in: commandBuffer)
                commandBuffer.commit()
            }
        }
    }
    
    private func updateProcessingParameters()
    {
        guard let processingParametersMetalBuffer = self.processingParametersMetalBuffer,
            let gain = self.gain,
            let dynamicRange = self.dynamicRange else {
                return
        }
        
        let processingParameters = ProcessingParameters(speedOfSoundInMillimetersPerSecond:
            self.speedOfSoundInMillimetersPerSecond,
                                                        fNumber: self.fNumber,
                                                        imageStartXInMillimeters: self.imageRangeXInMillimeters.lowerBound,
                                                        imageStartZInMillimeters: self.imageRangeZInMillimeters.lowerBound,
                                                        gain: gain,
                                                        dynamicRange: dynamicRange)
        
        let imageSize = self.imageSize
        self.numberOfPixels = imageSize.width * imageSize.height
        
        let processingContents = processingParametersMetalBuffer.contents().bindMemory(to: ProcessingParameters.self, capacity: 1)
        processingContents.pointee = processingParameters
    }
    
    var imageSize: (width: Int, height: Int) {
        get {
            // iPhone 6S 375x667 or 750x1334
            let width = Int(round((self.imageRangeXInMillimeters.upperBound - self.imageRangeXInMillimeters.lowerBound) / self.imageXPixelSpacing))
            let height = Int(round((self.imageRangeZInMillimeters.upperBound - self.imageRangeZInMillimeters.lowerBound) / self.imageZPixelSpacing))
//            print("Width: \(width), Height: \(height)")
            return (width: width, height: height)
        }
    }
    var lambda: Float {
        get {
            guard let centralFrequencyHz = self.probeParameters?.centralFrequencyHz else {
                return 0
            }
            return self.speedOfSoundInMillimetersPerSecond / (1.0 * centralFrequencyHz)
        }
    }
    var imageXPixelSpacing: Float {
        get {
            return self.lambda / 2 // Spacing between pixels in x_direction
        }
    }
    var imageZPixelSpacing: Float {
        get {
            return self.lambda / 2 // Spacing between pixels in z_direction
        }
    }
}

