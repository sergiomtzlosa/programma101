#import "PCSNumber.h"

@interface PCSNumber ()
+ (instancetype)pcs_makeWithSign:(NSInteger)sign digits:(NSString *)digits scale:(NSInteger)scale;
- (NSComparisonResult)compareMagnitude:(PCSNumber *)other;
@end

static NSString *PCSStripLeadingZeros(NSString *s) {
    NSUInteger i = 0;
    while (i + 1 < s.length && [s characterAtIndex:i] == '0') {
        i++;
    }
    return [s substringFromIndex:i];
}

static NSString *PCSZeros(NSUInteger count) {
    if (count == 0) return @"";
    NSMutableString *s = [NSMutableString stringWithCapacity:count];
    for (NSUInteger i = 0; i < count; i++) [s appendString:@"0"];
    return s;
}

static NSComparisonResult PCSCompareMagnitudes(NSString *a, NSString *b) {
    NSString *x = PCSStripLeadingZeros(a);
    NSString *y = PCSStripLeadingZeros(b);
    if (x.length != y.length) {
        return x.length < y.length ? NSOrderedAscending : NSOrderedDescending;
    }
    return [x compare:y options:NSLiteralSearch];
}

static NSString *PCSAddMagnitudes(NSString *a, NSString *b) {
    NSUInteger la = a.length, lb = b.length;
    NSUInteger n = MAX(la, lb);
    unichar *buf = calloc(n + 1, sizeof(unichar));
    int carry = 0;
    for (NSUInteger k = 0; k < n; k++) {
        int da = (k < la) ? [a characterAtIndex:la - 1 - k] - '0' : 0;
        int db = (k < lb) ? [b characterAtIndex:lb - 1 - k] - '0' : 0;
        int sum = da + db + carry;
        buf[n - k] = (unichar)('0' + (sum % 10));
        carry = sum / 10;
    }
    buf[0] = (unichar)('0' + carry);
    NSString *result = [NSString stringWithCharacters:buf length:n + 1];
    free(buf);
    return PCSStripLeadingZeros(result);
}

static NSString *PCSSubtractMagnitudes(NSString *a, NSString *b) {
    // Requires a >= b.
    NSUInteger la = a.length, lb = b.length;
    unichar *buf = calloc(la, sizeof(unichar));
    int borrow = 0;
    for (NSUInteger k = 0; k < la; k++) {
        int da = [a characterAtIndex:la - 1 - k] - '0';
        int db = (k < lb) ? [b characterAtIndex:lb - 1 - k] - '0' : 0;
        int d = da - db - borrow;
        borrow = 0;
        if (d < 0) {
            d += 10;
            borrow = 1;
        }
        buf[la - 1 - k] = (unichar)('0' + d);
    }
    NSString *result = [NSString stringWithCharacters:buf length:la];
    free(buf);
    return PCSStripLeadingZeros(result);
}

static NSString *PCSMultiplyMagnitudes(NSString *a, NSString *b) {
    a = PCSStripLeadingZeros(a);
    b = PCSStripLeadingZeros(b);
    if ([a isEqualToString:@"0"] || [b isEqualToString:@"0"]) return @"0";
    NSUInteger la = a.length, lb = b.length;
    NSUInteger len = la + lb;
    int *work = calloc(len, sizeof(int));
    for (NSInteger i = (NSInteger)la - 1; i >= 0; i--) {
        int da = [a characterAtIndex:i] - '0';
        for (NSInteger j = (NSInteger)lb - 1; j >= 0; j--) {
            int db = [b characterAtIndex:j] - '0';
            work[i + j + 1] += da * db;
        }
    }
    for (NSInteger k = (NSInteger)len - 1; k > 0; k--) {
        work[k - 1] += work[k] / 10;
        work[k] %= 10;
    }
    unichar *buf = calloc(len, sizeof(unichar));
    for (NSUInteger k = 0; k < len; k++) buf[k] = (unichar)('0' + work[k]);
    free(work);
    NSString *result = [NSString stringWithCharacters:buf length:len];
    free(buf);
    return PCSStripLeadingZeros(result);
}

/// Long division of magnitudes. Returns quotient (nil if divisor is zero).
static NSString *PCSDivideMagnitudes(NSString *dividend, NSString *divisor, NSString **remainderOut) {
    dividend = PCSStripLeadingZeros(dividend);
    divisor = PCSStripLeadingZeros(divisor);
    if ([divisor isEqualToString:@"0"]) return nil;
    if (PCSCompareMagnitudes(dividend, divisor) == NSOrderedAscending) {
        if (remainderOut) *remainderOut = dividend;
        return @"0";
    }
    NSMutableString *quotient = [NSMutableString stringWithCapacity:dividend.length];
    NSString *remainder = @"0";
    for (NSUInteger i = 0; i < dividend.length; i++) {
        unichar c = [dividend characterAtIndex:i];
        NSString *digitString = [NSString stringWithCharacters:&c length:1];
        remainder = PCSAddMagnitudes(PCSMultiplyMagnitudes(remainder, @"10"), digitString);
        int chosen = 0;
        for (int d = 9; d >= 1; d--) {
            NSString *product = PCSMultiplyMagnitudes(divisor, [NSString stringWithFormat:@"%d", d]);
            if (PCSCompareMagnitudes(product, remainder) != NSOrderedDescending) {
                chosen = d;
                remainder = PCSSubtractMagnitudes(remainder, product);
                break;
            }
        }
        [quotient appendFormat:@"%d", chosen];
    }
    if (remainderOut) *remainderOut = PCSStripLeadingZeros(remainder);
    return PCSStripLeadingZeros(quotient);
}

/// Integer square root (floor) of a decimal magnitude string.
static NSString *PCSSqrtMagnitude(NSString *n) {
    n = PCSStripLeadingZeros(n);
    if ([n isEqualToString:@"0"]) return @"0";
    NSUInteger len = n.length;
    NSMutableString *guess = [NSMutableString stringWithString:@"1"];
    for (NSUInteger i = 0; i < (len + 1) / 2; i++) [guess appendString:@"0"];
    // Newton iteration from above.
    while (YES) {
        NSString *q = PCSDivideMagnitudes(n, guess, NULL);
        NSString *sum = PCSAddMagnitudes(guess, q);
        NSString *next = PCSDivideMagnitudes(sum, @"2", NULL);
        if (PCSCompareMagnitudes(next, guess) != NSOrderedAscending) break;
        guess = [next mutableCopy];
    }
    // Correct any rounding drift.
    while (YES) {
        NSString *next = PCSAddMagnitudes(guess, @"1");
        NSString *square = PCSMultiplyMagnitudes(next, next);
        if (PCSCompareMagnitudes(square, n) != NSOrderedDescending) {
            guess = [next mutableCopy];
        } else {
            break;
        }
    }
    while (PCSCompareMagnitudes(PCSMultiplyMagnitudes(guess, guess), n) == NSOrderedDescending) {
        guess = [PCSSubtractMagnitudes(guess, @"1") mutableCopy];
    }
    return guess;
}

static PCSNumber *PCSMakeNumber(NSInteger sign, NSString *digits, NSInteger scale) {
    return [PCSNumber pcs_makeWithSign:sign digits:digits scale:scale];
}

@implementation PCSNumber {
    NSInteger _sign;
    NSString *_digits;
    NSInteger _scale;
}

+ (instancetype)pcs_makeWithSign:(NSInteger)sign digits:(NSString *)digits scale:(NSInteger)scale {
    PCSNumber *n = [PCSNumber new];
    digits = PCSStripLeadingZeros(digits);
    if ([digits isEqualToString:@"0"] || sign == 0) {
        n->_sign = 0;
        n->_digits = @"0";
        n->_scale = 0;
        return n;
    }
    // Canonicalise: drop insignificant trailing fractional zeros.
    while (scale > 0 && digits.length > 1 && [digits characterAtIndex:digits.length - 1] == '0') {
        digits = [digits substringToIndex:digits.length - 1];
        scale--;
    }
    n->_sign = sign < 0 ? -1 : 1;
    n->_digits = [digits copy];
    n->_scale = MAX(scale, 0);
    return n;
}

+ (instancetype)zero {
    static PCSNumber *zero;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ zero = PCSMakeNumber(0, @"0", 0); });
    return zero;
}

+ (instancetype)numberWithString:(NSString *)string {
    if (![string isKindOfClass:[NSString class]]) return nil;
    NSString *s = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (s.length == 0) return nil;
    NSInteger sign = 1;
    unichar first = [s characterAtIndex:0];
    if (first == '+') {
        s = [s substringFromIndex:1];
    } else if (first == '-') {
        sign = -1;
        s = [s substringFromIndex:1];
    }
    if (s.length == 0) return nil;
    NSArray<NSString *> *parts = [s componentsSeparatedByString:@"."];
    if (parts.count > 2) return nil;
    NSString *integerPart = parts[0];
    NSString *fractionPart = parts.count == 2 ? parts[1] : @"";
    for (NSUInteger i = 0; i < integerPart.length; i++) {
        unichar c = [integerPart characterAtIndex:i];
        if (!(c >= '0' && c <= '9')) return nil;
    }
    for (NSUInteger i = 0; i < fractionPart.length; i++) {
        unichar c = [fractionPart characterAtIndex:i];
        if (!(c >= '0' && c <= '9')) return nil;
    }
    if (integerPart.length == 0) integerPart = @"0";
    NSString *digits = [integerPart stringByAppendingString:fractionPart];
    NSInteger scale = (NSInteger)fractionPart.length;
    return PCSMakeNumber(sign, digits, scale);
}

+ (instancetype)numberWithInteger:(long long)value {
    return PCSMakeNumber(value < 0 ? -1 : (value == 0 ? 0 : 1),
                         [NSString stringWithFormat:@"%llu", value < 0 ? (unsigned long long)(-value) : (unsigned long long)value],
                         0);
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isZero { return _sign == 0; }
- (BOOL)isPositive { return _sign > 0; }

- (double)doubleValue {
    return [[self stringValue] doubleValue];
}

- (NSString *)stringValue {
    if (_sign == 0) return @"0";
    NSMutableString *s = [NSMutableString string];
    if (_sign < 0) [s appendString:@"-"];
    if (_scale == 0) {
        [s appendString:_digits];
        return s;
    }
    NSMutableString *d = [_digits mutableCopy];
    while ((NSInteger)d.length <= _scale) [d insertString:@"0" atIndex:0];
    NSUInteger point = d.length - (NSUInteger)_scale;
    [s appendString:[d substringToIndex:point]];
    [s appendString:@"."];
    [s appendString:[d substringFromIndex:point]];
    return s;
}

- (NSString *)stringValueWithDecimalPlaces:(NSInteger)places {
    if (places < 0) places = 0;
    PCSNumber *truncated = [self truncatedToDecimalPlaces:places];
    if (truncated.isZero) {
        if (places == 0) return @"0";
        return [@"0." stringByAppendingString:PCSZeros((NSUInteger)places)];
    }
    NSMutableString *s = [NSMutableString string];
    if (truncated.sign < 0) [s appendString:@"-"];
    NSMutableString *d = [truncated.digits mutableCopy];
    if (places == 0) {
        [s appendString:d];
        return s;
    }
    // Pad the fractional part out to `places` digits, then insert the point.
    for (NSInteger i = truncated.scale; i < places; i++) [d appendString:@"0"];
    while ((NSInteger)d.length <= places) [d insertString:@"0" atIndex:0];
    NSUInteger point = d.length - (NSUInteger)places;
    [s appendString:[d substringToIndex:point]];
    [s appendString:@"."];
    [s appendString:[d substringFromIndex:point]];
    return s;
}

- (instancetype)negated {
    if (_sign == 0) return self;
    return PCSMakeNumber(-_sign, _digits, _scale);
}

- (instancetype)absoluteValue {
    if (_sign >= 0) return self;
    return PCSMakeNumber(1, _digits, _scale);
}

- (instancetype)fractionalPart {
    if (_sign == 0 || _scale == 0) return [PCSNumber zero];
    if ((NSInteger)_digits.length <= _scale) return self;
    NSString *fractionDigits = [_digits substringFromIndex:_digits.length - (NSUInteger)_scale];
    return PCSMakeNumber(_sign, fractionDigits, _scale);
}

- (instancetype)truncatedToDecimalPlaces:(NSInteger)places {
    if (places < 0) places = 0;
    if (_scale <= places || _sign == 0) return self;
    NSInteger drop = _scale - places;
    if ((NSInteger)_digits.length <= drop) return [PCSNumber zero];
    NSString *kept = [_digits substringToIndex:_digits.length - (NSUInteger)drop];
    return PCSMakeNumber(_sign, kept, places);
}

- (instancetype)truncatedToSignificantDigits:(NSInteger)digits {
    if (digits <= 0) return [PCSNumber zero];
    if (_sign == 0 || (NSInteger)_digits.length <= digits) return self;
    NSInteger drop = (NSInteger)_digits.length - digits;
    NSString *kept = [_digits substringToIndex:(NSUInteger)digits];
    if (drop <= _scale) {
        return PCSMakeNumber(_sign, kept, _scale - drop);
    }
    NSString *padded = [kept stringByAppendingString:PCSZeros((NSUInteger)(drop - _scale))];
    return PCSMakeNumber(_sign, padded, 0);
}

- (instancetype)adding:(PCSNumber *)other {
    if (!other) return self;
    if (_sign == 0) return other;
    if (other.sign == 0) return self;
    NSInteger targetScale = MAX(_scale, other.scale);
    NSString *a = [_digits stringByAppendingString:PCSZeros((NSUInteger)(targetScale - _scale))];
    NSString *b = [other.digits stringByAppendingString:PCSZeros((NSUInteger)(targetScale - other.scale))];
    if (_sign == other.sign) {
        return PCSMakeNumber(_sign, PCSAddMagnitudes(a, b), targetScale);
    }
    NSComparisonResult cmp = PCSCompareMagnitudes(a, b);
    if (cmp == NSOrderedSame) return [PCSNumber zero];
    if (cmp == NSOrderedDescending) {
        return PCSMakeNumber(_sign, PCSSubtractMagnitudes(a, b), targetScale);
    }
    return PCSMakeNumber(other.sign, PCSSubtractMagnitudes(b, a), targetScale);
}

- (instancetype)subtracting:(PCSNumber *)other {
    return [self adding:[other negated]];
}

- (instancetype)multiplying:(PCSNumber *)other {
    if (!other || _sign == 0 || other.sign == 0) return [PCSNumber zero];
    return PCSMakeNumber(_sign * other.sign,
                         PCSMultiplyMagnitudes(_digits, other.digits),
                         _scale + other.scale);
}

- (instancetype)dividingBy:(PCSNumber *)other decimalPlaces:(NSInteger)places {
    if (!other || other.sign == 0) return nil;
    if (_sign == 0) return [PCSNumber zero];
    if (places < 0) places = 0;
    NSInteger shift = places + other.scale - _scale;
    NSString *numerator = _digits;
    NSString *denominator = other.digits;
    if (shift >= 0) {
        numerator = [numerator stringByAppendingString:PCSZeros((NSUInteger)shift)];
    } else {
        denominator = [denominator stringByAppendingString:PCSZeros((NSUInteger)(-shift))];
    }
    NSString *quotient = PCSDivideMagnitudes(numerator, denominator, NULL);
    if (!quotient) return nil;
    return PCSMakeNumber(_sign * other.sign, quotient, places);
}

- (instancetype)squareRootWithDecimalPlaces:(NSInteger)places {
    if (_sign < 0) return nil;
    if (_sign == 0) return [PCSNumber zero];
    if (places < 0) places = 0;
    NSInteger shift = 2 * places - _scale;
    NSString *radicand = _digits;
    if (shift >= 0) {
        radicand = [radicand stringByAppendingString:PCSZeros((NSUInteger)shift)];
    } else {
        NSInteger drop = -shift;
        if ((NSInteger)radicand.length <= drop) {
            radicand = @"0";
        } else {
            radicand = [radicand substringToIndex:radicand.length - (NSUInteger)drop];
        }
    }
    NSString *root = PCSSqrtMagnitude(radicand);
    return PCSMakeNumber(1, root, places);
}

- (NSComparisonResult)compare:(PCSNumber *)other {
    if (!other) return NSOrderedDescending;
    if (_sign != other.sign) {
        return _sign < other.sign ? NSOrderedAscending : NSOrderedDescending;
    }
    if (_sign == 0) return NSOrderedSame;
    NSComparisonResult mag = [self compareMagnitude:other];
    return _sign > 0 ? mag : (NSComparisonResult)(-mag);
}

- (NSComparisonResult)compareMagnitude:(PCSNumber *)other {
    NSInteger targetScale = MAX(_scale, other.scale);
    NSString *a = [_digits stringByAppendingString:PCSZeros((NSUInteger)(targetScale - _scale))];
    NSString *b = [other.digits stringByAppendingString:PCSZeros((NSUInteger)(targetScale - other.scale))];
    return PCSCompareMagnitudes(a, b);
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PCSNumber %@>", [self stringValue]];
}

@end
