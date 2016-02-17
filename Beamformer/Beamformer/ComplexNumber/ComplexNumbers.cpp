#include "ComplexNumbers.hpp"

#include <cmath>



ComplexF add(ComplexF lhs, ComplexF rhs)
{
    return { lhs.real + rhs.real, lhs.imaginary + rhs.imaginary };
}

ComplexF multiply(ComplexF lhs, ComplexF rhs)
{
    return { lhs.real * rhs.real - lhs.imaginary * rhs.imaginary, lhs.real * rhs.imaginary + rhs.real * lhs.imaginary };
}

float abs(ComplexF lhs)
{
    return sqrtf(lhs.real * lhs.real + lhs.imaginary * lhs.imaginary);
}
