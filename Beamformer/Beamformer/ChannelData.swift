import Foundation
import Accelerate



public struct ChannelData : CustomStringConvertible, Equatable
{
    public var channelIdentifier: Int
    public var complexVector: ComplexVector
    public var numberOfSamples: Int {
        get {
            return self.complexVector.count
        }
    }
    public var description: String {
        let name = String(self.dynamicType)
        return String(format: "%s %d samples", arguments: [name, self.numberOfSamples])
    }

    public init(channelIdentifier: Int, numberOfSamples: Int)
    {
        self.channelIdentifier = channelIdentifier
        self.complexVector = ComplexVector(count: numberOfSamples, repeatedValue: 0)
    }
}

extension ChannelData : ByteCountable
{
    func byteCount() -> Int
    {
        return sizeofValue(self.channelIdentifier) + self.complexVector.byteCount()
    }
}

public func ==(lhs: ChannelData, rhs: ChannelData) -> Bool
{
    return lhs.channelIdentifier == rhs.channelIdentifier && lhs.complexVector == rhs.complexVector
}