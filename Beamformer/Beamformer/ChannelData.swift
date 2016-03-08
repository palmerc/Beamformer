import Foundation



public struct ChannelData
{
    public var complexSamples: [ComplexNumber]
    public var samplesPerChannel: Int
}

extension ChannelData: CustomStringConvertible {
    public var description: String {
        let name = String(self.dynamicType)
        return String(format: "%s %d samples with %d samples per channel", arguments: [name, self.complexSamples.count, self.samplesPerChannel])
    }
}

extension ChannelData: Equatable {}

public func ==(lhs: ChannelData, rhs: ChannelData) -> Bool
{
    return lhs.complexSamples == rhs.complexSamples
}