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

extension ComplexVector : ByteCountable
{
    func byteCount() -> Int {
        return sizeofValue(self.real) + sizeofValue(self.imaginary) * self.count * 2
    }
}

public func ==(lhs: ComplexVector, rhs: ComplexVector) -> Bool
{
    return lhs.real! == rhs.real! && lhs.imaginary! == rhs.imaginary!
}
