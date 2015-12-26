//
//  VerasonicsFrame.swift
//  Beamformer
//
//  Created by Cameron Palmer on 26.12.2015.
//  Copyright © 2015 NTNU. All rights reserved.
//

import Foundation
import ObjectMapper


class VerasonicsFrame: NSObject, Mappable {
    var channelData: [[Int]]?
    var identifier: UInt?

    required init?(_ map: Map) {

    }

    func mapping(map: Map) {
        channelData    <- map["channel_data"]
        identifier     <- map["identifier"]
    }
}
