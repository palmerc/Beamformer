import Foundation
import ObjectMapper



public class VerasonicsFrame: NSObject, Mappable
{
    public var identifier: UInt!
    private var rawChannelData: [[Float]]!
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

    private var _channelData: ChannelData?
    public var channelData: ChannelData? {
        get {
            if self._channelData == nil {
                if self.numberOfChannels > 0 {
                    var complexSamples = [ComplexNumber](count: self.numberOfChannels * self.numberOfSamplesPerChannel, repeatedValue: ComplexNumber(real: 0, imaginary: 0))
                    for channelIndex in 0 ..< self.numberOfChannels {
                        var channelRawSamples = self.rawChannelData[channelIndex]
                        for sampleIndex in 0 ..< self.numberOfSamplesPerChannel {
                            let realIndex = sampleIndex * 2
                            let imaginaryIndex = realIndex + 1
                            let complexSampleIndex = channelIndex * self.numberOfSamplesPerChannel + sampleIndex
                            let complexSample = ComplexNumber(real: channelRawSamples[realIndex], imaginary: channelRawSamples[imaginaryIndex])
                            complexSamples[complexSampleIndex] = complexSample
                        }
                    }

                    self._channelData = ChannelData(complexSamples: complexSamples, samplesPerChannel: self.numberOfSamplesPerChannel)
                }
            }
            
            return self._channelData
        }
    }

    required public init?(_ map: Map) {

    }

    public func mapping(map: Map) {
        self.identifier        <- map["identifier"]
        self.rawChannelData    <- map["channel_data"]
    }
}
