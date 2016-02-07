import Foundation



public struct ChannelDelayData
{
    public var channelIdentifier: Int
    public var delays: [Float]

    public init(channelIdentifier: Int, numberOfDelays: Int)
    {
        self.channelIdentifier = channelIdentifier
        self.delays = [Float](count: numberOfDelays, repeatedValue: 0)
    }
}