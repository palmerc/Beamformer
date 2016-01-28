import Foundation



public struct ChannelDelayData
{
    public var channelIdentifier: Int
    public var delays: [Double]

    public init(channelIdentifier: Int, numberOfDelays: Int)
    {
        self.channelIdentifier = channelIdentifier
        self.delays = [Double](count: numberOfDelays, repeatedValue: 0)
    }
}