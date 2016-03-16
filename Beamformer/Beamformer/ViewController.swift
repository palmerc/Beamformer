import UIKit
import SwiftWebSocket
import ObjectMapper



class ViewController: UIViewController {
    @IBOutlet weak var ultrasoundImageView: UIImageView!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var framesPerSecondLabel: UILabel!

    let queue: dispatch_queue_t = dispatch_queue_create("no.uio.TestDataQueue", nil);

    let shouldDumpFrame: Bool = false
    let shouldUseWebSocket: Bool = false
    var measurement: Float = 0.0
    var framesPerSecondFormatter: NSNumberFormatter!

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
            let ws = WebSocket("ws://yankee.local:9000")
            ws.services = [ .VoIP, .Background ]
            self.webSocket = ws
        }

        let image = UIImage(named: "Horse07")?.CGImage
        let horse = UIImage(CGImage: image!, scale: 1.0, orientation: UIImageOrientation.Down)
        self.ultrasoundImageView.image = horse

        if let webSocket = self.webSocket {
            webSocket.event.message = { message in
                if let message = message as? String {
                    self.processFrame(message, withCompletionHandler: nil)
                }
            }
        } else {
            print("Test data loop starting...")
            self.testDataLoop(0)
        }

        self.connect = false
    }

    func testDataLoop(frameNumber: Int)
    {
        let webSocketFrameURLs = self.filesMatchingExtension("ws")
        if let webSocketFrameURLs = webSocketFrameURLs {
            let frameCount = webSocketFrameURLs.count
            if frameNumber < frameCount {
                let webSocketFrameURL = webSocketFrameURLs[frameNumber]
                var message: String?
                do {
                    let text = try NSString.init(contentsOfURL: webSocketFrameURL, encoding: NSUTF8StringEncoding)
                    message = text as String
                } catch {}

                if let message = message {
                    processFrame(message, withCompletionHandler: {
                        dispatch_async(dispatch_get_main_queue(), {
                            var nextFrameNumber = frameNumber + 1
                            if nextFrameNumber >= frameCount {
                                nextFrameNumber = 0
                            }

                            self.testDataLoop(nextFrameNumber)
                        })
                    })
                }
            }
        } else {
            print("No frames in the documents directory.")
        }
    }

    func processFrame(message: String, withCompletionHandler handler: (() -> ())?)
    {
        dispatch_async(self.queue) {
            self.dispatchFrame(message)
            if let handler = handler {
                handler()
            }
        }
    }

    private func dispatchFrame(message: String)
    {
        let verasonicsFrame = Mapper<VerasonicsFrame>().map(message)
        if self.shouldDumpFrame {
            if let documentsDirectory = self.documentsDirectory() {
                let number = verasonicsFrame!.identifier!
                let path = documentsDirectory.path! as NSString
                let filename = path.stringByAppendingPathComponent("Frame\(number).ws")
                self.dumpFrameWithFile(filename, text: message)
            }
        }

        let executionTime = self.executionTimeInterval({
            let image = self.verasonicsFrameProcessor.imageFromVerasonicsFrame(verasonicsFrame)

            dispatch_async(dispatch_get_main_queue(), {
                if image != nil {
                    self.ultrasoundImageView.image = image
                }
            })
        })

        dispatch_async(dispatch_get_main_queue(), {
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

        })
    }

    private func executionTimeInterval(block: () -> ()) -> CFTimeInterval
    {
        let start = CACurrentMediaTime()
        block()
        let end = CACurrentMediaTime()
        return end - start
    }

    private func dumpFrameWithFile(filename: String, text: String)
    {
        do {
            try text.writeToFile(filename, atomically: false, encoding: NSUTF8StringEncoding)
        } catch {}
    }

    private func filesMatchingExtension(fileExtension: String) -> [NSURL]?
    {
        var fileURLs: [NSURL]?
        if let documentsDirectory = self.documentsDirectory() {
            do {
                let files = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsDirectory, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.init(rawValue: 0))
                var matchingFiles = [NSURL]()
                for file in files {
                    let pathExtension = file.pathExtension
                    if pathExtension == fileExtension {
                        matchingFiles.append(file)
                    }
                }
                matchingFiles.sortInPlace({
                    (lhs: NSURL, rhs: NSURL) -> Bool in
                    let leftHandPath = lhs.absoluteString
                    let rightHandPath = rhs.absoluteString
                    let options = NSStringCompareOptions.CaseInsensitiveSearch.union(.NumericSearch)
                    return leftHandPath.compare(rightHandPath, options: options) == NSComparisonResult.OrderedAscending
                })
                if matchingFiles.count > 0 {
                    fileURLs = matchingFiles
                }
            } catch {}
        }

        return fileURLs
    }

    private func documentsDirectory() -> NSURL?
    {
        var documentsDirectory: NSURL?
        if let directory: NSString = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            documentsDirectory = NSURL.init(fileURLWithPath: directory as String, isDirectory: true)
        }

        return documentsDirectory
    }

    @IBAction func didPressConnectButton(sender: AnyObject)
    {
        self.connect = !self.connect
    }
}


