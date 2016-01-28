import Foundation
import Accelerate



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