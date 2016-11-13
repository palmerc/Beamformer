#import "VerasonicsFrameJSON.h"



static NSString *const kVerasonicsFrameJSONKeyIdentifier = @"identifier";
static NSString *const kVerasonicsFrameJSONKeyTimestamp = @"timestamp";
static NSString *const kVerasonicsFrameJSONKeyLensCorrection = @"lens_correction";
static NSString *const kVerasonicsFrameJSONKeySamplingFrequency = @"sampling_frequency";
static NSString *const kVerasonicsFrameJSONKeyChannelCount = @"number_of_channels";
static NSString *const kVerasonicsFrameJSONKeySamplesPerChannelCount = @"number_of_samples_per_channel";
static NSString *const kVerasonicsFrameJSONKeyChannelData = @"channel_data";



@interface VerasonicsFrameJSON ()
@property (strong, nonatomic, readonly) NSDictionary *dispatchTable;
@end



@implementation VerasonicsFrameJSON

- (instancetype)initWithJSONData:(NSData *)JSONData
{
    self = [super init];
    if (self) {
        self.complexSamples = NULL;
        [self deserializeJSONData:JSONData];
    }

    return self;
}

- (NSData *)JSONData
{
    NSDictionary *dictionary = @{kVerasonicsFrameJSONKeyIdentifier: @(self.identifier),
                                 kVerasonicsFrameJSONKeyTimestamp: @(self.timestamp),
                                 kVerasonicsFrameJSONKeyLensCorrection: @(self.lensCorrection),
                                 kVerasonicsFrameJSONKeySamplingFrequency: @(self.samplingFrequency),
                                 kVerasonicsFrameJSONKeyChannelCount: @(self.numberOfChannels),
                                 kVerasonicsFrameJSONKeySamplesPerChannelCount: @(self.numberOfSamplesPerChannel),
                                 kVerasonicsFrameJSONKeyChannelData: @(1)};
    NSMutableArray *mutableComplexSamples = [[NSMutableArray alloc] initWithCapacity:self.numberOfSamples];
    NSUInteger length = [self.complexSamples length];
    NSUInteger chunkSize = sizeof(int16_t);
    NSUInteger chunkOffset = 0;

    do {
        chunkSize = MIN(length - chunkOffset, chunkSize);

        NSData *chunk = [self.complexSamples subdataWithRange:NSMakeRange(chunkOffset, chunkSize)];
        chunkOffset = chunkOffset + chunkSize;
        int16_t value = (int16_t)chunk.bytes;
        [mutableComplexSamples addObject:@(value)];
    } while (chunkOffset < length);

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:NSJSONWritingPrettyPrinted error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }

    return data;
}

- (void)deserializeJSONData:(NSData *)JSONData
{
    NSError *error = nil;
    NSDictionary *JSONObject = [NSJSONSerialization JSONObjectWithData:JSONData options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    }

    [self updateWithDictionary:JSONObject];
}

- (void)updateWithDictionary:(NSDictionary *)dictionary
{
    for (NSString *key in [dictionary keyEnumerator]) {
        id JSONValue = [dictionary objectForKey:key];

        SEL selector = [[self.dispatchTable valueForKey:key] pointerValue];
        if (selector != NULL && [self respondsToSelector:selector]) {
            IMP imp = [self methodForSelector:selector];
            void (*method)(id, SEL, id) = (void *)imp;
            method(self, selector, JSONValue);
        } else {
            NSLog(@"No selector found for pair - %@: %@", key, JSONValue);
        }
    }
}

- (NSDictionary *)dispatchTable
{
    return @{
             kVerasonicsFrameJSONKeyIdentifier: [NSValue valueWithPointer:@selector(setIdentifierWithNumber:)],
             kVerasonicsFrameJSONKeyTimestamp: [NSValue valueWithPointer:@selector(setTimestampWithNumber:)],
             kVerasonicsFrameJSONKeyLensCorrection: [NSValue valueWithPointer:@selector(setLensCorrectionWithNumber:)],
             kVerasonicsFrameJSONKeySamplingFrequency: [NSValue valueWithPointer:@selector(setSamplingFrequencyWithNumber:)],
             kVerasonicsFrameJSONKeyChannelCount: [NSValue valueWithPointer:@selector(setChannelCountWithNumber:)],
             kVerasonicsFrameJSONKeySamplesPerChannelCount: [NSValue valueWithPointer:@selector(setSamplesPerChannelCountWithNumber:)],
             kVerasonicsFrameJSONKeyChannelData: [NSValue valueWithPointer:@selector(setComplexSamplesWithArray:)]
             };
}

- (void)setIdentifierWithNumber:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)value;
        self.identifier = [number integerValue];
    }
}

- (void)setTimestampWithNumber:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *timestamp = (NSNumber *)value;
        NSTimeInterval milliseconds = timestamp.doubleValue;
        NSTimeInterval timeInterval = milliseconds / 1000.f;
        self.timestamp = timeInterval;
    }
}

- (void)setLensCorrectionWithNumber:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *lensCorrection = (NSNumber *)value;
        self.lensCorrection = lensCorrection.doubleValue;
    }
}

- (void)setSamplingFrequencyWithNumber:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *samplingFrequency = (NSNumber *)value;
        self.samplingFrequency = samplingFrequency.doubleValue;
    }
}

- (void)setChannelCountWithNumber:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)value;
        self.numberOfChannels = (int32_t)[number intValue];
    }
}

- (void)setSamplesPerChannelCountWithNumber:(id)value
{
    if ([value isKindOfClass:[NSNumber class]]) {
        NSNumber *number = (NSNumber *)value;
        self.numberOfSamplesPerChannel = (int32_t)[number intValue];
    }
}

- (void)setComplexSamplesWithArray:(id)value
{
    if ([value isKindOfClass:[NSArray class]]) {
        NSArray<NSNumber *> *array = (NSArray<NSNumber *> *)value;
        NSMutableData *complexSamples = [NSMutableData dataWithLength:array.count * sizeof(int16_t)];
        int16_t *underlyingBytes = complexSamples.mutableBytes;
        for (int i = 0; i < array.count; i++) {
            underlyingBytes[i] = (int16_t)array[i].intValue;
        }

        self.complexSamples = complexSamples;
    }
}

@end
