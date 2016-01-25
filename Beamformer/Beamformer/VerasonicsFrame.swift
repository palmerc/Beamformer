//
//  VerasonicsFrame.swift
//  Beamformer
//
//  Created by Cameron Palmer on 26.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

import Foundation
import ObjectMapper


public class VerasonicsFrame: NSObject, Mappable
{
    var channelData: [[Int]]?
    var identifier: UInt?
//    override var description: String
//    {
//        return 
//    }

    required public init?(_ map: Map) {

    }

    public func mapping(map: Map) {
        channelData    <- map["channel_data"]
        identifier     <- map["identifier"]
    }
}
