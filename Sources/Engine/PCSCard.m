#import "PCSCard.h"
#import "PCSProgram.h"

NSString *const PCSCardErrorDomain = @"PCS101CardErrorDomain";

@interface PCSCard ()
@property (nonatomic, strong) NSMutableArray<PCS101Program *> *mutableStripes;
@end

@implementation PCSCard

+ (NSRegularExpression *)stripeRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"^#\\s*stripe\\s+([12])"
                                                         options:NSRegularExpressionCaseInsensitive error:NULL];
    });
    return regex;
}

+ (instancetype)cardWithProgram:(PCS101Program *)program {
    return [self cardWithPrograms:program ? @[program] : @[]];
}

+ (instancetype)cardWithProgram:(PCS101Program *)program
                      constants:(NSDictionary<NSString *,PCSNumber *> *)constants {
    if (!program || constants.count == 0) {
        return [self cardWithProgram:program];
    }
    PCS101Program *recorded = [program programByMergingConstants:constants] ?: program;
    return [self cardWithProgram:recorded];
}

+ (instancetype)cardWithPrograms:(NSArray<PCS101Program *> *)programs {
    PCSCard *card = [PCSCard new];
    card.mutableStripes = [programs mutableCopy];
    if (card.mutableStripes.count > 2) {
        card.mutableStripes = [[card.mutableStripes subarrayWithRange:NSMakeRange(0, 2)] mutableCopy];
    }
    return card;
}

+ (instancetype)cardWithText:(NSString *)text error:(NSError **)error {
    if (![text isKindOfClass:[NSString class]]) {
        if (error) *error = [NSError errorWithDomain:PCSCardErrorDomain code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Card data is missing."}];
        return nil;
    }
    NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSMutableArray<NSMutableString *> *stripeTexts = [NSMutableArray array];
    NSMutableString *current = nil;
    BOOL sawMarker = NO;

    for (NSString *line in lines) {
        NSRange range = NSMakeRange(0, line.length);
        NSTextCheckingResult *match = [[self stripeRegex] firstMatchInString:line options:0 range:range];
        if (match) {
            sawMarker = YES;
            current = [NSMutableString string];
            [stripeTexts addObject:current];
            continue;
        }
        if (current) {
            [current appendFormat:@"%@\n", line];
        }
    }

    if (!sawMarker) {
        // A plain .prg file is accepted as a single-stripe card.
        [stripeTexts addObject:[text mutableCopy]];
    }

    PCSCard *card = [PCSCard new];
    card.mutableStripes = [NSMutableArray array];
    for (NSMutableString *stripeText in stripeTexts) {
        if ([[stripeText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0) {
            continue;
        }
        PCS101Program *program = [PCS101Program programWithText:stripeText error:error];
        if (!program) return nil;
        [card.mutableStripes addObject:program];
    }
    return card;
}

- (NSArray<PCS101Program *> *)stripes {
    return [self.mutableStripes copy];
}

- (PCS101Program *)programForStripe:(NSInteger)stripeIndex {
    if (stripeIndex < 0 || stripeIndex >= (NSInteger)self.mutableStripes.count) return nil;
    return self.mutableStripes[(NSUInteger)stripeIndex];
}

- (NSString *)textRepresentation {
    NSMutableString *out = [NSMutableString string];
    [out appendString:@"# Programma 101 magnetic card\n"];
    NSInteger count = MAX((NSInteger)self.mutableStripes.count, 1);
    for (NSInteger i = 0; i < count; i++) {
        [out appendFormat:@"# stripe %ld\n", (long)(i + 1)];
        if (i < (NSInteger)self.mutableStripes.count) {
            [out appendString:[self.mutableStripes[(NSUInteger)i] textRepresentation]];
        }
    }
    return out;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PCSCard %lu stripe(s)>", (unsigned long)self.mutableStripes.count];
}

@end
