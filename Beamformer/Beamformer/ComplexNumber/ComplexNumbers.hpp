#ifndef ComplexNumbers_h
#define ComplexNumbers_h

#include <cmath>



struct ComplexF {
    float real;
    float imaginary;
    ComplexF(float r, float i) : real(r), imaginary(i) {};
};



ComplexF add(ComplexF lhs, ComplexF rhs);
ComplexF multiply(ComplexF lhs, ComplexF rhs);
float abs(ComplexF lhs);

#endif
