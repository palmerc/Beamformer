#include "ComplexNumbers.hpp"

#include <cmath>



ComplexNumberF add(ComplexNumberF lhs, ComplexNumberF rhs)
{
    return { lhs.real + rhs.real, lhs.imaginary + rhs.imaginary };
}
ComplexNumberF subtract(ComplexNumberF lhs, ComplexNumberF rhs)
{
    return { lhs.real - rhs.real, lhs.imaginary - rhs.imaginary };
}
ComplexNumberF multiply(ComplexNumberF lhs, ComplexNumberF rhs)
{
    return { lhs.real * rhs.real - lhs.imaginary * rhs.imaginary, lhs.real * rhs.imaginary + rhs.real * lhs.imaginary };
}
