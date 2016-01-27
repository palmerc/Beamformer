import Foundation
import Accelerate



public struct ChannelData
{
    public var channelIdentifier: Int
    public var real: [Double]
    public var imaginary: [Double]
    public var numberOfSamples: Int
    {
        get {
            return self.real.count
        }
    }

    private var generatedComplexData: [Complex<Double>]?
    public var complexIQVector: [Complex<Double>]
    {
        mutating get {
            if (self.generatedComplexData == nil) {
                self.generatedComplexData = real.enumerate().map({ (index: Int, real: Double) -> Complex<Double> in
                    return Complex<Double>(real + imaginary[index].i)
                })
            }

            return self.generatedComplexData!
        }
    }

    public init(channelIdentifier: Int, numberOfSamples: Int)
    {
        self.channelIdentifier = channelIdentifier
        self.real = [Double](count: numberOfSamples, repeatedValue: 0)
        self.imaginary = [Double](count: numberOfSamples, repeatedValue: 0)
    }
}