import Foundation



public struct ChannelDelay
{
    public var identifier: Int
    public var delays: [Float]

    public init(channelIdentifier: Int, numberOfDelays: Int)
    {
        self.identifier = channelIdentifier
        self.delays = [Float](count: numberOfDelays, repeatedValue: 0)
    }
}