import UIKit
import SwiftWebSocket
import ObjectMapper



class ViewController: UIViewController {
    @IBOutlet weak var ultrasoundImageView: UIImageView!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var framesPerSecondLabel: UILabel!

    var executing: Bool = false
    var measurement: Float = 0.0
    var framesPerSecondFormatter: NSNumberFormatter!

    lazy var verasonicsFrameProcessor = VerasonicsFrameProcessor(withElementPositions: VerasonicsFrameProcessor.transducerElementPositionsInMMs)
    var webSocket: WebSocket!

    var isConnected: Bool?
    var connect: Bool {
        get {
            return self.isConnected!
        }
        set {
            if (newValue) {
                self.webSocket.open()
                self.connectButton.setTitle("Disconnect", forState: UIControlState.Normal)
            } else {
                self.webSocket.close()
                self.connectButton.setTitle("Connect", forState: UIControlState.Normal)
            }
            self.isConnected = newValue
        }
    }

    deinit
    {
        self.webSocket.close()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        framesPerSecondFormatter = NSNumberFormatter()
        framesPerSecondFormatter.numberStyle = .DecimalStyle
        framesPerSecondFormatter.minimumFractionDigits = 1
        framesPerSecondFormatter.maximumFractionDigits = 2

        let ws = WebSocket("ws://yankee.local:9000")
        ws.services = [ .VoIP, .Background ]
        self.webSocket = ws

        let image = UIImage(named: "Horse07")?.CGImage
        let horse = UIImage(CGImage: image!, scale: 1.0, orientation: UIImageOrientation.Down)
        self.ultrasoundImageView.image = horse

        self.webSocket.event.message = { message in
            if !self.executing {
                self.executing = true
                if let message = message as? String {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                        self.processFrame(message)
                    })
                }
            }
        }

        self.connect = false
    }

    func processFrame(message: String?)
    {
        if let message = message {
            let verasonicsFrame = Mapper<VerasonicsFrame>().map(message)
            let executionTime = self.executionTimeInterval({
                let image = self.verasonicsFrameProcessor.imageFromVerasonicsFrame(verasonicsFrame)
                dispatch_async(dispatch_get_main_queue(), {
                    if image != nil {
                        self.ultrasoundImageView.image = image
                    }
                    self.executing = false
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
    }

    func executionTimeInterval(block: () -> ()) -> CFTimeInterval
    {
        let start = CACurrentMediaTime()
        block();
        let end = CACurrentMediaTime()
        return end - start
    }

    @IBAction func didPressConnectButton(sender: AnyObject) {
        self.connect = !self.connect
    }
}


