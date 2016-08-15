@import Foundation;



@protocol JSONSerializable <NSObject>
- (instancetype)initWithJSONData:(NSData *)JSONData;
- (NSData *)JSONData;

@end
