import Foundation



public struct ChannelData
{
    public var channelIdentifier: Int
    public var complexVector: ComplexVector
    
    public var numberOfSamples: Int {
        get {
            return self.complexVector.count
        }
    }

    public init(channelIdentifier: Int, numberOfSamples: Int)
    {
        self.channelIdentifier = channelIdentifier
        self.complexVector = ComplexVector(count: numberOfSamples, repeatedValue: 0)
    }
}

extension ChannelData: CustomStringConvertible
{
    public var description: String {
        let name = String(self.dynamicType)
        return String(format: "%s %d samples", arguments: [name, self.numberOfSamples])
    }
}

extension ChannelData: Equatable {}

public func ==(lhs: ChannelData, rhs: ChannelData) -> Bool
{
    return lhs.channelIdentifier == rhs.channelIdentifier && lhs.complexVector == rhs.complexVector
}