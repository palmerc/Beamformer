import Foundation



public struct ComplexVector
{
    public var real: [Double]?
    public var imaginary: [Double]?
    public var count: Int {
        get {
            var count = 0
            if self.real != nil {
                count = self.real!.count / 2
            }
            return count
        }
    }

    init()
    {
        self.real = nil
        self.imaginary = nil
    }

    init(count: Int, repeatedValue: Double)
    {
        self.real = [Double](count: count, repeatedValue: repeatedValue)
        self.imaginary = [Double](count: count, repeatedValue: repeatedValue)
    }
}
