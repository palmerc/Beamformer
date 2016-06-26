@import Foundation;



@protocol JSONSerializable <NSObject>
- (instancetype)initWithJSONData:(NSData *)JSONData;

@end
