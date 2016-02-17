#import "NSValue+BFComplexNumber.h"



@implementation NSValue (BFComplexNumber)

+ (NSValue *)valueWithBFComplexNumber:(BFComplexNumber)complexNumber
{
    return [NSValue valueWithBytes:&complexNumber objCType:@encode(BFComplexNumber)];
}

- (BFComplexNumber)BFComplexNumberValue
{
    BFComplexNumber complexNumber;

    [self getValue:&complexNumber];

    return complexNumber;
}

@end
