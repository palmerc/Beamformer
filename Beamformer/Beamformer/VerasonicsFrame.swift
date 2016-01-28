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
                    for channelIndex in 0 ..< numberOfChannels {
                        channelData![channelIndex].channelIdentifier = channelIndex
//                        var real = [Double]()
//                        real.reserveCapacity(self.numberOfSamplesPerChannel)
//                        var imaginary = [Double]()
//                        imaginary.reserveCapacity(self.numberOfSamplesPerChannel)
//                        for (index, rawChannelData) in self.rawChannelData[channelIndex].enumerate() {
//                            if index % 2 == 0 {
//                                real.append(Double(rawChannelData))
//                            } else {
//                                imaginary.append(Double(rawChannelData))
//                            }
//                        }
                        let real = self.rawChannelData[channelIndex].enumerate().filter({
                            (index: Int, element: Int) -> Bool in
                            return index % 2 == 0
                        }).map({ (_: Int, element: Int) -> Double in
                            return Double(element)
                        })
                        let imaginary = self.rawChannelData[channelIndex].enumerate().filter({
                            (index: Int, element: Int) -> Bool in
                            return index % 2 != 0
                        }).map({ (_: Int, element: Int) -> Double in
                            return Double(element)
                        })

                        channelData![channelIndex].complexVector.real = real
                        channelData![channelIndex].complexVector.imaginary = imaginary
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
