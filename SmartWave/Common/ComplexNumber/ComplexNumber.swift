import Foundation



public struct ComplexNumber
{
    var real: Float
    var imaginary: Float
}

public func +(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber
{
    return ComplexNumber(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
}

public func *(lhs: ComplexNumber, rhs: ComplexNumber) -> ComplexNumber
{
    return ComplexNumber(real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
        imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real)
}
public func *(lhs: ComplexNumber, rhs: Float) -> ComplexNumber
{
    return ComplexNumber(real: lhs.real * rhs, imaginary: lhs.imaginary * rhs)
}
public func *(lhs: Float, rhs: ComplexNumber) -> ComplexNumber
{
    return ComplexNumber(real: lhs * rhs.real, imaginary: lhs * rhs.imaginary)
}
public func *=(inout lhs: ComplexNumber, rhs: ComplexNumber)
{
    lhs = lhs * rhs
}
public func *=(inout lhs: ComplexNumber, rhs: Float)
{
    lhs = lhs * rhs
}
public func abs(lhs: ComplexNumber) -> Float
{
    return sqrt(lhs.real * lhs.real + lhs.imaginary * lhs.imaginary)
}

extension ComplexNumber: Equatable {}
public func ==(lhs: ComplexNumber, rhs: ComplexNumber) -> Bool
{
    return lhs.real == rhs.real && lhs.imaginary == rhs.imaginary
}

extension ComplexNumber: CustomStringConvertible
{
    public var description: String {
        let name = String(self.dynamicType)
        let sign = self.imaginary < 0 ? "-" : "+"
        return String(format: "%s %f %s %fi", arguments: [name, self.real, sign, self.imaginary])
    }
}