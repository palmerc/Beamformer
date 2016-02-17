@import Foundation;

#import "BFComplexNumber.h"



@interface NSValue (BFComplexNumber)

+ (NSValue *)valueWithBFComplexNumber:(BFComplexNumber)complexNumber;

- (BFComplexNumber)BFComplexNumberValue;

@end
