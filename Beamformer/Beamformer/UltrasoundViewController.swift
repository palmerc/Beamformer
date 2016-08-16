import UIKit
import SwiftWebSocket
import ObjectMapper



let ultrasoundToServerSelectionSegueIdentifier = "ultrasoundToServerSelectionSegueIdentifier"

struct FrameTimeSample
{
    let frameNumber: Int
    let GPUProcessingTime: Double
    let networkProcessingTime: Double
}

class UltrasoundViewController: UIViewController, ServerSelectionDelegate
{
    @IBOutlet var ultrasoundImageView: UIImageView!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var frameNumberLabel: UILabel!
    @IBOutlet var networkFramesPerSecondLabel: UILabel!
    @IBOutlet var GPUFramesPerSecondLabel: UILabel!

    let queue: dispatch_queue_t = dispatch_queue_create("no.uio.TestDataQueue", nil)

    var frameTimeSamples = [FrameTimeSample]()
    var GPUTimeMeasurement: Float = 0
    var networkTimeMeasurement: Float = 0
    var framesPerSecondFormatter: NSNumberFormatter!
    var inflightFrames = 0
    var maxInflightFrames = 1

    lazy var verasonicsFrameProcessor = VerasonicsFrameProcessor(withElementPositions: VerasonicsFrameProcessor.transducerElementPositionsInMMs)

    var webSocket: WebSocket?
    var _selectedService: NSNetService?
    var selectedService: NSNetService? {
        get {
            return self._selectedService
        }
        set {
            let selectedService = newValue

            if let webSocket = self.webSocket {
                webSocket.close()
            }

            if selectedService != nil {
                let webSocket = WebSocket()
                webSocket.services = [.Background]
                webSocket.binaryType = .NSData
                webSocket.event.open = {
                    print("Opened WebSocket connection to \(webSocket.url).")
                }
                webSocket.event.close = { code, reason, clean in
                    print("Closed WebSocket connection.")

                    if self.frameTimeSamples.count > 0 {
                        self.recordSamples()
                        self.frameTimeSamples.removeAll()
                    }
                }
                webSocket.event.error = { error in
                    print("WebSocket error \(error)")
                }
                webSocket.event.message = { message in
                    if let compressedData = message as? NSData {
                        let frameData = compressedData.uncompressedDataUsingCompression(Compression.ZLIB)
                        let versonicsFrame = VerasonicsFrameJSON(JSONData: frameData)
                        self.processFrameData(versonicsFrame, withCompletionHandler: nil)
                    }
                }

                self.webSocket = webSocket
            }

            self._selectedService = selectedService

        }
    }



    // MARK: ViewController lifecycle

    deinit
    {
        if let webSocket = self.webSocket {
            webSocket.close()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        framesPerSecondFormatter = NSNumberFormatter()
        framesPerSecondFormatter.numberStyle = .DecimalStyle
        framesPerSecondFormatter.minimumFractionDigits = 1
        framesPerSecondFormatter.maximumFractionDigits = 2

        let uioSeal = UIImage(named: "UiO Seal")
        self.ultrasoundImageView.image = uioSeal


//            print("Test data loop starting...")
//            dispatch_async(dispatch_get_main_queue(), {
//                self.testDataLoop(0)
//            })

    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if segue.identifier == ultrasoundToServerSelectionSegueIdentifier {
            let navigationController = segue.destinationViewController as? UINavigationController
            let serverSelectionViewController = navigationController?.visibleViewController as? ServerSelectionViewController
            serverSelectionViewController?.delegate = self
            serverSelectionViewController?.selectedService = self.selectedService
        }
    }



    // MARK: Frame processing

    func testDataLoop(frameNumber: Int)
    {
        if let defaultDataset = DatasetManager.defaultManager().defaultDataset() {
            let webSocketFrameURLs = defaultDataset.fileURLs
            let frameCount = webSocketFrameURLs.count

            let webSocketFrameURL = webSocketFrameURLs[frameNumber]
            let verasonicsFrameData = DatasetManager.defaultManager().cachedDataWithURL(webSocketFrameURL)
            if let verasonicsFrame = VerasonicsFrameJSON(JSONData: verasonicsFrameData) {
                processFrameData(verasonicsFrame, withCompletionHandler: {
                    var nextNumber = frameNumber + 1
                    if nextNumber >= frameCount {
                        nextNumber = 0
                    }

                    self.testDataLoop(nextNumber)
                })
            }
        }
    }

    func processFrameData(verasonicsFrame: VerasonicsFrame, withCompletionHandler handler: (() -> ())?)
    {
        dispatch_sync(self.queue, {
            self.dispatchFrame(verasonicsFrame, withCompletionHandler: handler)
        })
    }

    private func dispatchFrame(verasonicsFrame: VerasonicsFrame?, withCompletionHandler handler: (() -> ())?)
    {
        let GPUProcessingStartTime = CACurrentMediaTime()
        self.verasonicsFrameProcessor.imageFromVerasonicsFrame(verasonicsFrame, withCompletionHandler: {
            (image: UIImage) in
            dispatch_async(dispatch_get_main_queue(), {
                self.inflightFrames = self.inflightFrames - 1
                self.ultrasoundImageView.image = image

                if let frameNumber = verasonicsFrame?.identifier,
                    verasonicsFrameTimestamp = verasonicsFrame?.timestamp {
                    self.frameNumberLabel.text = "Frame \(frameNumber)"

                    let GPUProcessingEndTime = CACurrentMediaTime()
                    let GPUProcessingTime = GPUProcessingEndTime - GPUProcessingStartTime
                    self.GPUProcessingTime(GPUProcessingTime)

                    let now = NSDate().timeIntervalSince1970
                    let networkProcessingTime = now - verasonicsFrameTimestamp
                    self.networkProcessingTime(networkProcessingTime)

                    let frameTimeSample = FrameTimeSample(frameNumber: frameNumber, GPUProcessingTime: GPUProcessingTime, networkProcessingTime: networkProcessingTime)
                    self.frameTimeSamples.append(frameTimeSample)
                }

                if let handler = handler {
                    handler()
                }
            })
        })
    }



    // MARK: ServerSelectionDelegate
    func didSelectNetService(service: NSNetService?)
    {
        self.selectedService = service
    }



    // MARK: IBActions

    @IBAction func didPressConnectButton(sender: AnyObject)
    {
        self.performSegueWithIdentifier(ultrasoundToServerSelectionSegueIdentifier, sender: nil)
    }

    @IBAction func unwindToUltrasoundViewController(segue: UIStoryboardSegue)
    {
        // Intentionally left blank
        if let webSocket = self.webSocket,
            service = self.selectedService,
            address = service.humanReadableIPAddresses()?.first {
                let port = service.port
                let URLString = "ws://\(address):\(port)"
            dispatch_async(dispatch_get_main_queue(), { 
                webSocket.open(URLString)
            })
        }
    }



    // MARK: Utility methods

    private func recordSamples()
    {
        var lines = [String]()
        let header = "FRAME_NO, GPU_TIME, NET_TIME"
        lines.append(header)
        for frameTimeSample in self.frameTimeSamples {
            let line = String(format: "%d, %f, %f", frameTimeSample.frameNumber, frameTimeSample.GPUProcessingTime, frameTimeSample.networkProcessingTime)
            lines.append(line)
        }

        let imageSize = self.verasonicsFrameProcessor.imageSize
        let documentsDirectory = DatasetManager.documentsDirectory()
        let filename = String(format: "samples-%dx%d.csv", Int(imageSize.width), Int(imageSize.height))
        if let documentURL = documentsDirectory?.URLByAppendingPathComponent(filename),
        filePath = documentURL.path {
            let document = lines.joinWithSeparator("\n")
            do {
                try document.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding)
            } catch let error as NSError {
                print("\(error)")
            }
        }
        print("Samples written to file - \(filename)")
    }

    private func networkProcessingTime(executionTime: CFTimeInterval)
    {
        if self.networkTimeMeasurement > 0 {
            let smoothing: Float = 0.6
            self.networkTimeMeasurement = (self.networkTimeMeasurement * smoothing) + (Float(executionTime) * (1.0 - smoothing))
            let framesPerSecond = 1.0 / self.networkTimeMeasurement

            if let fpsText = self.framesPerSecondFormatter.stringFromNumber(framesPerSecond) {
                let labelText = "\(fpsText) Net FPS"
                self.networkFramesPerSecondLabel.text = labelText
                print("\(labelText) - \(executionTime)")
            }
        } else {
            self.networkTimeMeasurement = Float(executionTime)
        }
    }

    private func GPUProcessingTime(executionTime: CFTimeInterval)
    {
        if self.GPUTimeMeasurement > 0 {
            let smoothing: Float = 0.6
            self.GPUTimeMeasurement = (self.GPUTimeMeasurement * smoothing) + (Float(executionTime) * (1.0 - smoothing))
            let framesPerSecond = 1.0 / self.GPUTimeMeasurement

            if let fpsText = self.framesPerSecondFormatter.stringFromNumber(framesPerSecond) {
                let labelText = "\(fpsText) GPU FPS"
                self.GPUFramesPerSecondLabel.text = labelText
                print("\(labelText) - \(executionTime)")
            }
        } else {
            self.GPUTimeMeasurement = Float(executionTime)
        }
    }
}

