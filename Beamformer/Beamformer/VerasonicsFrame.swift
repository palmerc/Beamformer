import Foundation
import ObjectMapper



public class VerasonicsFrame: NSObject, Mappable
{
    public var identifier: Int?
    public var numberOfChannels: Int?
    public var numberOfSamplesPerChannel: Int?
    public var channelData: ChannelData?

    private var _rawChannelData: [[Int]]?
    private var rawChannelData: [[Int]]? {
        set {
            if let rawChannelData = newValue,
                numberOfChannels = self.numberOfChannels,
                numberOfSamplesPerChannel = self.numberOfSamplesPerChannel {
                self._rawChannelData = rawChannelData

                let numberOfSampleValuesPerChannel = numberOfSamplesPerChannel * 2
                let numberOfSampleValues = numberOfChannels * numberOfSampleValuesPerChannel
                    var complexSamples = [Int16](count: numberOfSampleValues, repeatedValue: 0)

                    for channelIndex in 0 ..< numberOfChannels {
                        var channelRawSamples = rawChannelData[channelIndex]
                        for sampleIndex in 0 ..< numberOfSampleValuesPerChannel {//
                            let complexSampleIndex = channelIndex * numberOfSampleValuesPerChannel + sampleIndex
                            complexSamples[complexSampleIndex] = Int16(channelRawSamples[sampleIndex])
                        }

                        self.channelData = ChannelData(complexSamples: complexSamples, numberOfChannels: numberOfChannels, numberOfSamplesPerChannel: numberOfSamplesPerChannel)
                }
            }
        }
        get {
            return self._rawChannelData
        }
    }

    required public init?(_ map: Map) {

    }

    public func mapping(map: Map) {
        self.identifier                <- map["identifier"]
        self.numberOfChannels          <- map["number_of_channels"]
        self.numberOfSamplesPerChannel <- map["number_of_samples_per_channel"]
        self.rawChannelData            <- map["channel_data"]
    }
}
