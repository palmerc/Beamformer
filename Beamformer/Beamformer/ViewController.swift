import UIKit
import SwiftWebSocket
import ObjectMapper



class ViewController: UIViewController {
    @IBOutlet var ultrasoundImageView: UIImageView!
    @IBOutlet var connectButton: UIButton!
    @IBOutlet var framesPerSecondLabel: UILabel!

    let queue: dispatch_queue_t = dispatch_queue_create("no.uio.TestDataQueue", nil)

    var shouldLoop = false
    let shouldDumpFrame: Bool = false
    let shouldUseWebSocket: Bool = false
    var measurement: Float = 0.0
    var framesPerSecondFormatter: NSNumberFormatter!
    var inflightFrames = 0
    var maxInflightFrames = 1

    lazy var verasonicsFrameProcessor = VerasonicsFrameProcessor(withElementPositions: VerasonicsFrameProcessor.transducerElementPositionsInMMs)
    var webSocket: WebSocket?

    var isConnected: Bool?
    var connect: Bool {
        get {
            return self.isConnected!
        }
        set {
            if (newValue) {
                if let webSocket = self.webSocket {
                    webSocket.open()
                }
                self.connectButton.setTitle("Disconnect", forState: UIControlState.Normal)
            } else {
                if let webSocket = self.webSocket {
                    webSocket.close()
                }
                self.connectButton.setTitle("Connect", forState: UIControlState.Normal)
            }
            self.isConnected = newValue
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

        framesPerSecondFormatter = NSNumberFormatter()
        framesPerSecondFormatter.numberStyle = .DecimalStyle
        framesPerSecondFormatter.minimumFractionDigits = 1
        framesPerSecondFormatter.maximumFractionDigits = 2

        if shouldUseWebSocket {
            let ws = WebSocket("ws://193.157.117.38:9000")
            ws.services = [ .Background ]
            self.webSocket = ws
        }

        let image = UIImage(named: "Horse07")?.CGImage
        let horse = UIImage(CGImage: image!, scale: 1.0, orientation: UIImageOrientation.Down)
        self.ultrasoundImageView.image = horse

        if let webSocket = self.webSocket {
            webSocket.event.message = { message in
                if let message = message as? String where
                    self.inflightFrames < self.maxInflightFrames {
                    let compressedData = NSData(base64EncodedString: message, options: NSDataBase64DecodingOptions(rawValue: 0))
                    let frameData = compressedData?.uncompressedDataUsingCompression(Compression.ZLIB)
                    let versonicsFrame = VerasonicsFrameJSON(JSONData: frameData)
                    self.processFrameData(versonicsFrame, withCompletionHandler: nil)
                    self.inflightFrames = self.inflightFrames + 1
                }
            }
        } else {
            print("Test data loop starting...")
            dispatch_async(dispatch_get_main_queue(), {
                self.testDataLoop(0)
            })
        }

        self.connect = false
    }

    func testDataLoop(frameNumber: Int)
    {
        self.shouldLoop = true
        
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
//            if self.shouldDumpFrame {
//                self.dumpFrameData(data)
//            }
            self.dispatchFrame(verasonicsFrame, withCompletionHandler: handler)
        })
    }

    private func dispatchFrame(verasonicsFrame: VerasonicsFrame?, withCompletionHandler handler: (() -> ())?)
    {
        let startTime = CACurrentMediaTime()
        self.verasonicsFrameProcessor.imageFromVerasonicsFrame(verasonicsFrame, withCompletionHandler: {
            (image: UIImage) in
            dispatch_async(dispatch_get_main_queue(), {
                self.inflightFrames = self.inflightFrames - 1
                self.ultrasoundImageView.image = image
                let endTime = CACurrentMediaTime()
                let elapsedTime = endTime - startTime
                self.executionTime(elapsedTime)
                self.connectButton.setTitle("Frame \(verasonicsFrame?.identifier)", forState: .Normal)
                if let handler = handler {
                    handler()
                }
            })
        })
    }

    private func executionTime(executionTime: CFTimeInterval)
    {
        print("\(executionTime)")
        if self.measurement > 0 {
            let smoothing: Float = 0.6
            self.measurement = (self.measurement * smoothing) + (Float(executionTime) * (1.0 - smoothing))
            let framesPerSecond = 1.0 / self.measurement

            if let fpsText = self.framesPerSecondFormatter.stringFromNumber(framesPerSecond) {
                self.framesPerSecondLabel.text = "\(fpsText) FPS"
            }
        } else {
            self.measurement = Float(executionTime)
        }
    }

    private func dumpFrameData(data: NSData)
    {
//        if let documentsDirectory = self.documentsDirectory() {
//            let number = verasonicsFrame!.identifier!
//            let path = documentsDirectory.path! as NSString
//            let filename = path.stringByAppendingPathComponent("Frame\(number).ws")
//            self.dumpFrameWithFile(filename, text: message)
//        }
    }

    private func dumpFrameWithFile(filename: String, text: String)
    {
        do {
            try text.writeToFile(filename, atomically: false, encoding: NSUTF8StringEncoding)
        } catch {}
    }

    @IBAction func didPressConnectButton(sender: AnyObject)
    {
        self.connect = !self.connect
    }
}

