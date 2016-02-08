import Foundation



public struct ComplexVector : Equatable
{
    public var real: [Float]?
    public var imaginary: [Float]?
    public var count: Int {
        get {
            var count = 0
            if self.real != nil {
                count = self.real!.count
            }
            return count
        }
    }

    init()
    {
        self.real = nil
        self.imaginary = nil
    }

    init(count: Int, repeatedValue: Float)
    {
        self.real = [Float](count: count, repeatedValue: repeatedValue)
        self.imaginary = [Float](count: count, repeatedValue: repeatedValue)
    }
}

public func ==(lhs: ComplexVector, rhs: ComplexVector) -> Bool
{
    return lhs.real! == rhs.real! && lhs.imaginary! == rhs.imaginary!
}
