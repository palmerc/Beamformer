#ifndef ComplexNumbers_h
#define ComplexNumbers_h



typedef struct ComplexNumberF {
    float real;
    float imaginary;
} ComplexNumberF;

ComplexNumberF add(ComplexNumberF lhs, ComplexNumberF rhs);
ComplexNumberF subtract(ComplexNumberF lhs, ComplexNumberF rhs);
ComplexNumberF multiply(ComplexNumberF lhs, ComplexNumberF rhs);

#endif
