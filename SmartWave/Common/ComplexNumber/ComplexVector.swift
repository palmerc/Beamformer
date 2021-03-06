import Foundation



public struct ComplexVector {
    public var complexNumbers: [ComplexNumber]?

    public var reals: [Float]? {
        return complexNumbers?.map({
            (complexNumber: ComplexNumber) -> Float in
            return complexNumber.real
        })
    }

    public var imaginaries: [Float]? {
        return complexNumbers?.map({
            (complexNumber: ComplexNumber) -> Float in
            return complexNumber.imaginary
        })
    }

    public init(reals: [Float], imaginaries: [Float])
    {
        var complexNumbers = [ComplexNumber](repeating: (ComplexNumber(real: 0, imaginary: 0)), count: reals.count)
        for (index, real) in reals.enumerated() {
            complexNumbers[index].real = real
            complexNumbers[index].imaginary = imaginaries[index]
        }

        self.complexNumbers = complexNumbers
    }

    public init(complexNumbers: [ComplexNumber])
    {
        self.complexNumbers = complexNumbers
    }
}
