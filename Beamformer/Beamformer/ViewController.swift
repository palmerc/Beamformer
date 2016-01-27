import UIKit
import SwiftWebSocket
import ObjectMapper



class ViewController: UIViewController {
    @IBOutlet weak var UltrasoundImageView: UIImageView!
    @IBOutlet weak var ConnectButton: UIButton!

    lazy var webSocket = WebSocket()

    var isConnected: Bool?
    var connect: Bool {
        get {
            return self.isConnected!
        }
        set {
            if (newValue) {
                self.webSocket.open("ws://127.0.0.1:9000")
            } else {
                self.webSocket.close()
            }
            self.isConnected = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let processor = VerasonicsFrameProcessor(withDelays: VerasonicsFrameProcessor.defaultDelays)
        self.webSocket.event.message = { message in
            if let text = message as? String {
//                let data: NSData = text.dataUsingEncoding(NSUTF8StringEncoding)!
//                data.writeToFile("/Users/palmerc/frame.json", atomically: true)
                let verasonicsFrame = Mapper<VerasonicsFrame>().map(text)
                let executionTime = self.executionTimeInterval({ () -> () in
                    let image = processor.imageFromVerasonicsFrame(verasonicsFrame)
                    self.UltrasoundImageView.image = image
                })
                print("Execution time: \(executionTime) seconds")
            }
        }

        self.connect = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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

