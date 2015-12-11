//
//  ViewController.swift
//  Beamformer
//
//  Created by Cameron Palmer on 10.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var ConnectButton: UIButton!

    private let connection = Connection()

    var isConnected: Bool?
    var connect: Bool {
        get {
            return self.isConnected!
        }
        set {
            if (newValue) {
                self.connection.connect()
            } else {
                self.connection.disconnect()
            }
            self.isConnected = newValue
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.connect = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction func didPressConnectButton(sender: AnyObject) {
        self.connect = !self.connect
    }
}

