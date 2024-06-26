#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Exact decimal value in the range and representation of a Programma 101 register.
/// Value = sign * digits * 10^(-scale), digits is an unsigned decimal string (MSB first).
@interface PCSNumber : NSObject <NSCopying>

@property (nonatomic, readonly) NSInteger sign;       // -1, 0, +1
@property (nonatomic, readonly, copy) NSString *digits; // magnitude, no leading zeros
@property (nonatomic, readonly) NSInteger scale;      // number of decimal places

+ (instancetype)zero;
+ (nullable instancetype)numberWithString:(NSString *)string;
+ (instancetype)numberWithInteger:(long long)value;

- (BOOL)isZero;
- (BOOL)isPositive;
- (double)doubleValue;
- (NSString *)stringValue;
/// Formats the value truncated toward zero at `places` decimals, padded to exactly
/// `places` decimal digits (machine paper style).
- (NSString *)stringValueWithDecimalPlaces:(NSInteger)places;

- (instancetype)negated;
- (instancetype)absoluteValue;
- (instancetype)fractionalPart;
- (instancetype)truncatedToDecimalPlaces:(NSInteger)places;
- (instancetype)truncatedToSignificantDigits:(NSInteger)digits;

- (instancetype)adding:(PCSNumber *)other;
- (instancetype)subtracting:(PCSNumber *)other;
- (instancetype)multiplying:(PCSNumber *)other;
/// Truncated quotient. Returns nil for division by zero.
- (nullable instancetype)dividingBy:(PCSNumber *)other decimalPlaces:(NSInteger)places;
- (nullable instancetype)squareRootWithDecimalPlaces:(NSInteger)places;

- (NSComparisonResult)compare:(PCSNumber *)other;

@end

NS_ASSUME_NONNULL_END
