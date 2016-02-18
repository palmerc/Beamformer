import Foundation



public struct ComplexVector
{
    public var reals: [Float]?
    public var imaginaries: [Float]?

    public var BFComplexNumbers: [BFComplexNumber]? {
        return reals?.enumerate().map({
            (index: Int, real: Float) -> BFComplexNumber in
            let imaginary = self.imaginaries![index]
            return BFComplexNumber(real: real, imaginary: imaginary)
        })
    }

    public var zip: [(Float, Float)]? {
        return self.reals?.enumerate().map({
            (index: Int, real: Float) -> (Float, Float) in
            let imaginary = self.imaginaries![index]
            return (real, imaginary)
        })
    }
    public var count: Int {
        get {
            var count = 0
            if self.reals != nil {
                count = self.reals!.count
            }
            return count
        }
    }

    public init()
    {
        self.reals = nil
        self.imaginaries = nil
    }

    public init(count: Int, repeatedValue: Float)
    {
        self.reals = [Float](count: count, repeatedValue: repeatedValue)
        self.imaginaries = [Float](count: count, repeatedValue: repeatedValue)
    }

    public init(reals: [Float], imaginaries: [Float])
    {
        self.reals = reals
        self.imaginaries = imaginaries
    }
}

extension ComplexVector: Equatable {}

public func ==(lhs: ComplexVector, rhs: ComplexVector) -> Bool
{
    var result = false
    if lhs.reals != nil && rhs.reals != nil {
        result = lhs.reals! == rhs.reals! && lhs.imaginaries! == rhs.imaginaries!
    }

    return result
}
