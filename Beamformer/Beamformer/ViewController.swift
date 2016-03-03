import UIKit
import SwiftWebSocket
import ObjectMapper



class ViewController: UIViewController {
    @IBOutlet weak var ultrasoundImageView: UIImageView!
    @IBOutlet weak var connectButton: UIButton!

    var executing: Bool = false

    lazy var verasonicsFrameProcessor = VerasonicsFrameProcessor(withElementPositions: VerasonicsFrameProcessor.transducerElementPositionsInMMs)
    lazy var webSocket = WebSocket()

    var isConnected: Bool?
    var connect: Bool {
        get {
            return self.isConnected!
        }
        set {
            if (newValue) {
                self.webSocket.open("ws://yankee.local:9000")
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

        let image = UIImage(named: "Horse07")?.CGImage
        let horse = UIImage(CGImage: image!, scale: 1.0, orientation: UIImageOrientation.Down)
        self.ultrasoundImageView.image = horse

        self.webSocket.event.message = { message in
            if let text = message as? String {
                let verasonicsFrame = Mapper<VerasonicsFrame>().map(text)
                if self.executing == false {
                    self.executing = true
                    let executionTime = self.executionTimeInterval({
                        let image = self.verasonicsFrameProcessor.imageFromVerasonicsFrame(verasonicsFrame)
                        dispatch_async(dispatch_get_main_queue(), {
                            if image != nil {
                                self.ultrasoundImageView.image = image
                            }
                            self.executing = false
                        })
                    })
                    print("Execution time: \(executionTime) seconds")
                }
            }
        }

        self.connect = false
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


