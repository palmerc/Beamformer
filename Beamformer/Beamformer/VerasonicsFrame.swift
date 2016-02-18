import Foundation
import ObjectMapper



public class VerasonicsFrame: NSObject, Mappable
{
    public var identifier: UInt!
    private var rawChannelData: [[Int]]!
    public var numberOfChannels: Int {
        get {
            return self.rawChannelData.count
        }
    }
    public var numberOfSamplesPerChannel: Int {
        get {
            var count = 0
            let row = self.rawChannelData.first
            if row != nil {
                count = row!.count / 2
            }
            return count
        }
    }

    private var calculatedChannelData: [ChannelData]?
    public var channelData: [ChannelData]? {
        get {
            if self.calculatedChannelData == nil {
                var channelData: [ChannelData]?
                if self.numberOfChannels > 0 {
                    channelData = [ChannelData](count: self.numberOfChannels,
                        repeatedValue: ChannelData(channelIdentifier: 0, numberOfSamples: self.numberOfSamplesPerChannel))
                    for channelIndex in 0 ..< self.numberOfChannels {
                        channelData![channelIndex].channelIdentifier = channelIndex
                        let reals = self.rawChannelData[channelIndex].enumerate().filter({
                            (index: Int, element: Int) -> Bool in
                            return index % 2 == 0
                        }).map({ (_: Int, element: Int) -> Float in
                            return Float(element)
                        })
                        let imaginaries = self.rawChannelData[channelIndex].enumerate().filter({
                            (index: Int, element: Int) -> Bool in
                            return index % 2 != 0
                        }).map({ (_: Int, element: Int) -> Float in
                            return Float(element)
                        })

                        channelData![channelIndex].complexVector = ComplexVector(reals: reals, imaginaries: imaginaries)
                    }

                    self.calculatedChannelData = channelData
                }
            }
            
            return self.calculatedChannelData
        }
    }

    required public init?(_ map: Map) {

    }

    public func mapping(map: Map) {
        self.identifier        <- map["identifier"]
        self.rawChannelData    <- map["channel_data"]
    }
}
