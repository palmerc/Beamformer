import Foundation
import ObjectMapper



public class VerasonicsFrame: NSObject, Mappable
{
    public var identifier: Int?
    public var numberOfChannels: Int?
    public var numberOfSamplesPerChannel: Int?
    public var channelData: ChannelData?

    private var _rawChannelData: [[Float]]?
    private var rawChannelData: [[Float]]? {
        set {
            if let rawChannelData = newValue,
                numberOfChannels = self.numberOfChannels,
                numberOfSamplesPerChannel = self.numberOfSamplesPerChannel {
                self._rawChannelData = rawChannelData

                let numberOfSamples = numberOfChannels * numberOfSamplesPerChannel
                if self.numberOfChannels > 0 {
                    var complexSamples = [ComplexNumber](count: numberOfSamples, repeatedValue: ComplexNumber(real: 0, imaginary: 0))

                    for channelIndex in 0 ..< numberOfChannels {
                        var channelRawSamples = rawChannelData[channelIndex]
                        for sampleIndex in 0 ..< numberOfSamplesPerChannel {
                            let realIndex = sampleIndex * 2
                            let imaginaryIndex = realIndex + 1
                            let real = channelRawSamples[realIndex]
                            let imaginary = channelRawSamples[imaginaryIndex]

                            let complexSampleIndex = channelIndex * numberOfSamplesPerChannel + sampleIndex
                            complexSamples[complexSampleIndex].real = real
                            complexSamples[complexSampleIndex].imaginary = imaginary
                        }
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
