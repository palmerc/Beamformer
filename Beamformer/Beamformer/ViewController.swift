//
//  ViewController.swift
//  Beamformer
//
//  Created by Cameron Palmer on 10.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

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
                self.webSocket.open(url: "ws://127.0.0.1:9000")
            } else {
                self.webSocket.close()
            }
            self.isConnected = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let processor = VerasonicsDelay(withDelays: VerasonicsDelay.defaultDelays)
        self.webSocket.event.message = { message in
            if let text = message as? String {
                let verasonicsFrame = Mapper<VerasonicsFrame>().map(text)
                let image = processor.imageFromVerasonicsFrame(verasonicsFrame)
                self.UltrasoundImageView.image = image
            }
        }

        self.connect = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func didPressConnectButton(sender: AnyObject) {
        self.connect = !self.connect
    }
}

