import Cocoa
import MetalKit
import SocketRocket



let ultrasoundToServerSelectionSegueIdentifier = "ultrasoundToServerSelectionSegueIdentifier"

struct FrameTimeSample
{
    let frameNumber: Int
    let GPUProcessingTime: Double
    let networkProcessingTime: Double
}

protocol ServerSelectionDelegate
{
    func didSelectNetService(_ service: NetService?)
}

class UltrasoundViewControllerMacOS: NSViewController, SRWebSocketDelegate, ServerSelectionDelegate {
    var metalView: MTKView!
    //    @IBOutlet var connectButton: UIButton!
    //    @IBOutlet var frameNumberLabel: UILabel!
    //    @IBOutlet var networkFramesPerSecondLabel: UILabel!
    //    @IBOutlet var GPUFramesPerSecondLabel: UILabel!
    
    let queue: DispatchQueue = DispatchQueue(label: "no.uio.TestDataQueue", attributes: [])
    
    var verasonicsFrameProcessor: VerasonicsFrameProcessorMetal?
    var frameTimeSamples = [FrameTimeSample]()
    var timestamp: TimeInterval = 0
    var GPUTimeMeasurement: Float = 0
    var networkTimeMeasurement: Float = 0
    var framesPerSecondFormatter: NumberFormatter!
    var inflightFrames = 0
    var maxInflightFrames = 1
    
    var webSocket: SRWebSocket?
    var _selectedService: NetService?
    var selectedService: NetService? {
        get {
            return self._selectedService
        }
        set {
            let selectedService = newValue
            
            if let webSocket = self.webSocket {
                webSocket.close()
            }
            
            self._selectedService = selectedService
            
        }
    }
    
    
    
    deinit
    {
        if let webSocket = self.webSocket {
            webSocket.close()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let metalView = self.view as! MTKView
        metalView.device = MTLCreateSystemDefaultDevice();
        metalView.colorPixelFormat = .bgra8Unorm;
        metalView.clearColor = MTLClearColorMake(0, 0, 0, 1);
        
        metalView.drawableSize = metalView.bounds.size;
        
        self.verasonicsFrameProcessor = VerasonicsFrameProcessorMetal(with: metalView)
        self.metalView = metalView
        
        framesPerSecondFormatter = NumberFormatter()
        framesPerSecondFormatter.numberStyle = .decimal
        framesPerSecondFormatter.minimumFractionDigits = 1
        framesPerSecondFormatter.maximumFractionDigits = 2
        
        let address = "127.0.0.1"
        let port = 9080
        let URLString = "ws://\(address):\(port)"
        let URL = NSURL(string: URLString)
        if let webSocket = SRWebSocket(url: URL as URL!) {
            webSocket.delegate = self
            
            DispatchQueue.global().async(execute: {
                webSocket.open()
            })
            
            self.webSocket = webSocket
        }
        
        print("Test data loop starting...")
        DispatchQueue.main.async(execute: {
            self.testDataLoop(0)
        })
        
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    
    
    // MARK: ViewController lifecycle
    
    
    //    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    //    {
    //        if segue.identifier == ultrasoundToServerSelectionSegueIdentifier {
    //            let navigationController = segue.destinationViewController as? UINavigationController
    //            let serverSelectionViewController = navigationController?.visibleViewController as? ServerSelectionViewController
    //            serverSelectionViewController?.delegate = self
    //            serverSelectionViewController?.selectedService = self.selectedService
    //        }
    //    }
    
    
    
    // MARK: Frame processing
    
    func testDataLoop(_ frameNumber: Int)
    {
        if let defaultDataset = DatasetManager.defaultManager().defaultDataset() {
            let webSocketFrameURLs = defaultDataset.fileURLs
            let frameCount = webSocketFrameURLs.count
            
            let webSocketFrameURL = webSocketFrameURLs[frameNumber]
            if let verasonicsFrameData = DatasetManager.defaultManager().cachedDataWithURL(webSocketFrameURL) {
                do {
                    let frame = try Smartwave_VerasonicsPlaneWave(serializedData: verasonicsFrameData)
                    processFrameData(frame, withCompletionHandler: {
                        var nextNumber = frameNumber + 1
                        if nextNumber >= frameCount {
                            nextNumber = 0
                        }
                        
                        self.testDataLoop(nextNumber)
                    })
                } catch {
                    
                }
            }
        }
    }
    
    func processFrameData(_ verasonicsFrame: Smartwave_VerasonicsPlaneWave, withCompletionHandler handler: (() -> ())?)
    {
        self.queue.sync(execute: {
            dispatchFrame(verasonicsFrame, withCompletionHandler: handler)
        })
    }
    
    fileprivate func dispatchFrame(_ verasonicsFrame: Smartwave_VerasonicsPlaneWave?, withCompletionHandler handler: (() -> ())?)
    {
        self.verasonicsFrameProcessor?.enqueFrame(verasonicsFrame)
    }
    
    
    
    // MARK: ServerSelectionDelegate
    func didSelectNetService(_ service: NetService?)
    {
        self.selectedService = service
    }
    
    
    
    // MARK: SRWebSocketDelegate
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!)
    {
        if let frameData = message as? Data {
            self.bytesReceived(frameData.count)
            do {
                let versonicsFrame = try Smartwave_VerasonicsPlaneWave(serializedData: frameData)
                self.processFrameData(versonicsFrame, withCompletionHandler: nil)
            } catch let error {
                print("Cannot deserialize protobuf - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: IBActions
    
    @IBAction func didPressConnectButton(_ sender: AnyObject)
    {
        self.performSegue(withIdentifier: ultrasoundToServerSelectionSegueIdentifier, sender: nil)
    }
    
    //    @IBAction func unwindToUltrasoundViewController(segue: UIStoryboardSegue)
    //    {
    //        if let service = self.selectedService,
    //            let address = service.humanReadableIPAddresses()?.first {
    //            let port = service.port
    //            let URLString = "ws://\(address):\(port)"
    //            let URL = NSURL(string: URLString)
    //            if let webSocket = SRWebSocket(URL: URL) {
    //                webSocket.delegate = self
    //
    //                dispatch_async(dispatch_get_main_queue(), {
    //                    webSocket.open()
    //                })
    //
    //                self.webSocket = webSocket
    //            }
    //        }
    //    }
    
    
    
    // MARK: Utility methods
    
    fileprivate func recordSamples()
    {
        var lines = [String]()
        let header = "FRAME_NO, GPU_TIME, NET_TIME"
        lines.append(header)
        for frameTimeSample in self.frameTimeSamples {
            let line = String(format: "%d, %f, %f", frameTimeSample.frameNumber, frameTimeSample.GPUProcessingTime, frameTimeSample.networkProcessingTime)
            lines.append(line)
        }
        
        if let imageSize = self.verasonicsFrameProcessor?.imageSize {
            let documentsDirectory = DatasetManager.documentsDirectory()
            let filename = String(format: "samples-%dx%d.csv", Int(imageSize.width), Int(imageSize.height))
            if let documentURL = documentsDirectory?.appendingPathComponent(filename) {
                let document = lines.joined(separator: "\n")
                do {
                    try document.write(toFile: documentURL.path, atomically: true, encoding: String.Encoding.utf8)
                } catch let error as NSError {
                    print("\(error)")
                }
            }
            print("Samples written to file - \(filename)")
        }
    }
    
    fileprivate func bytesReceived(_ bytes: Int?)
    {
        guard let bytes = bytes else {
            return
        }
        
        let labelText = "\(bytes) bytes"
        print("\(labelText)")
    }
    
    fileprivate func bytesPerSecond(_ executionTime: CFTimeInterval)
    {
        //        if self.networkTimeMeasurement > 0 {
        //            let smoothing: Float = 0.6
        //            self.networkTimeMeasurement = (self.networkTimeMeasurement * smoothing) + (Float(executionTime) * (1.0 - smoothing))
        //            let framesPerSecond = 1.0 / self.networkTimeMeasurement
        //
        //            if let fpsText = self.framesPerSecondFormatter.stringFromNumber(framesPerSecond) {
        //                let labelText = "\(fpsText) Net FPS"
        //                self.networkFramesPerSecondLabel.text = labelText
        //                print("\(labelText) - \(executionTime)")
        //            }
        //        } else {
        //            self.networkTimeMeasurement = Float(executionTime)
        //        }
    }
    
    fileprivate func networkProcessingTime(_ executionTime: CFTimeInterval)
    {
        //        if self.networkTimeMeasurement > 0 {
        //            let smoothing: Float = 0.6
        //            self.networkTimeMeasurement = (self.networkTimeMeasurement * smoothing) + (Float(executionTime) * (1.0 - smoothing))
        //            let framesPerSecond = 1.0 / self.networkTimeMeasurement
        //
        //            if let fpsText = self.framesPerSecondFormatter.stringFromNumber(framesPerSecond) {
        //                let labelText = "\(fpsText) Net FPS"
        //                self.networkFramesPerSecondLabel.text = labelText
        //                print("\(labelText) - \(executionTime)")
        //            }
        //        } else {
        //            self.networkTimeMeasurement = Float(executionTime)
        //        }
    }
    
    fileprivate func GPUProcessingTime(_ executionTime: CFTimeInterval)
    {
        //        if self.GPUTimeMeasurement > 0 {
        //            let smoothing: Float = 0.6
        //            self.GPUTimeMeasurement = (self.GPUTimeMeasurement * smoothing) + (Float(executionTime) * (1.0 - smoothing))
        //            let framesPerSecond = 1.0 / self.GPUTimeMeasurement
        //
        //            if let fpsText = self.framesPerSecondFormatter.stringFromNumber(framesPerSecond) {
        //                let labelText = "\(fpsText) GPU FPS"
        //                self.GPUFramesPerSecondLabel.text = labelText
        //                print("\(labelText) - \(executionTime)")
        //            }
        //        } else {
        //            self.GPUTimeMeasurement = Float(executionTime)
        //        }
        //    }
    }
    
//    fileprivate func grayscaleImageFromPixelValues(_ pixelValues: Data?, width: Int, height: Int) -> NSImage?
//    {
//        var image: NSImage?
//
//        guard let pixelValues = pixelValues else {
//            return image
//        }
//
//        let colorSpaceRef = CGColorSpaceCreateDeviceGray()
//
//        let bitsPerComponent = 8
//        let bytesPerPixel = 1
//        let bitsPerPixel = bytesPerPixel * bitsPerComponent
//        let bytesPerRow = bytesPerPixel * width
//
//        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
//            .union(CGBitmapInfo())
//
//        let providerRef = CGDataProvider(data: pixelValues as CFData)
//
//        if let imageRef = CGImage(width: width,
//                                  height: height,
//                                  bitsPerComponent: bitsPerComponent,
//                                  bitsPerPixel: bitsPerPixel,
//                                  bytesPerRow: bytesPerRow,
//                                  space: colorSpaceRef,
//                                  bitmapInfo: bitmapInfo,
//                                  provider: providerRef!,
//                                  decode: nil,
//                                  shouldInterpolate: false,
//                                  intent: CGColorRenderingIntent.defaultIntent) {
//            image = NSImage(cgImage: imageRef, size: CGSize(width: width, height: height))
//        }
//
//        return image
//    }
}


