//
//  Connection.swift
//  Beamformer
//
//  Created by Cameron Palmer on 11.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

import Foundation

class Connection : NSObject, NSStreamDelegate {
    let defaultPortNumber = 30001
    let baseURL = NSURL(string: "http://localhost:30001")

    private var inputStream: NSInputStream?
    private var outputStream: NSOutputStream?

    func connect() {
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?

        let portNumber = CFURLGetPortNumber(baseURL)

        var unsignedPortNumber: UInt32 = UInt32(defaultPortNumber)
        if (portNumber > 0) {
            unsignedPortNumber = UInt32(portNumber)
        }
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, CFURLCopyHostName(baseURL), unsignedPortNumber, &readStream, &writeStream)

        self.inputStream = readStream!.takeRetainedValue()
        self.outputStream = writeStream!.takeRetainedValue()

        self.inputStream!.delegate = self
        self.outputStream!.delegate = self

        self.inputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode:NSDefaultRunLoopMode)
        self.outputStream!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode:NSDefaultRunLoopMode)

        self.inputStream!.open()
        self.outputStream!.open()
    }

    func disconnect() {
        self.inputStream?.close()
        self.outputStream?.close()
    }

    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        switch(eventCode) {
        case NSStreamEvent.OpenCompleted:
            NSLog("OpenCompleted")
            break
        case NSStreamEvent.HasBytesAvailable:
            NSLog("HasBytesAvailable")
            readAvailableBytes()
            break
        case NSStreamEvent.HasSpaceAvailable:
            NSLog("HasSpaceAvailable")
            break
        case NSStreamEvent.ErrorOccurred:
            NSLog("ErrorOccurred")
            break
        case NSStreamEvent.EndEncountered:
            NSLog("EndEncountered")
            break
        default:
            break
        }
    }

    func readAvailableBytes() {
        var length = 0
        var buffer = [UInt8](count:4096, repeatedValue:0)

        if (self.inputStream!.hasBytesAvailable) {
            length = self.inputStream!.read(&buffer, maxLength: buffer.count)
        }

        NSLog("%@", String(bytes: buffer, encoding: NSUTF8StringEncoding)!)
    }
}