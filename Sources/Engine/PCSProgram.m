#import "PCSProgram.h"
#import "PCSInstruction.h"
#import "PCSNumber.h"

NSString *const PCSProgramErrorDomain = @"PCS101ProgramErrorDomain";

static NSString *PCSConstantDirectiveKey(NSString *key) {
    if (key.length == 0) return key;
    NSString *lower = [key lowercaseString];
    if ([key isEqualToString:lower]) {
        return [[key uppercaseString] stringByAppendingString:@"/"];
    }
    return [key uppercaseString];
}

static NSString *PCSConstantCanonicalKey(NSString *key) {
    if (key.length == 0) return key;
    if ([key hasSuffix:@"/"]) {
        return [[key substringToIndex:key.length - 1] lowercaseString];
    }
    if (key.length == 1 && [key isEqualToString:[key lowercaseString]]) {
        return [key lowercaseString];
    }
    return [key uppercaseString];
}

@interface PCS101Program ()
@property (nonatomic, strong) NSMutableArray<PCS101Instruction *> *mutableInstructions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, PCSNumber *> *mutableConstants;
@property (nonatomic, strong) NSMutableArray<NSString *> *mutableComments;
@property (nonatomic, assign) NSInteger decimalWheel;
- (NSString *)textRepresentationWithConstants:(NSDictionary<NSString *, PCSNumber *> *)constants;
@end

@implementation PCS101Program

+ (NSRegularExpression *)wheelRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
                 @"(?i)decimal\\s+(?:wheel|indicator)\\s*(?:setting|position)?\\s*:?\\s*([0-9]{1,2})"
                                                         options:0 error:NULL];
    });
    return regex;
}

+ (NSRegularExpression *)constantRegex {
    static NSRegularExpression *regex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:
                 @"(?i)constant(?:\\s+on\\s+card)?\\s*:?\\s*([A-Fa-f](?:/)?)\\s*=\\s*(-?[0-9]*\\.?[0-9]+)"
                                                         options:0 error:NULL];
    });
    return regex;
}

+ (NSString *)canonicalRegisterKey:(NSString *)key {
    return PCSConstantCanonicalKey(key);
}

+ (nullable instancetype)programWithText:(NSString *)text error:(NSError **)error {
    if (![text isKindOfClass:[NSString class]]) {
        if (error) *error = [NSError errorWithDomain:PCSProgramErrorDomain code:1
                                             userInfo:@{NSLocalizedDescriptionKey: @"Program text is missing."}];
        return nil;
    }
    PCS101Program *program = [PCS101Program new];
    program.mutableInstructions = [NSMutableArray array];
    program.mutableConstants = [NSMutableDictionary dictionary];
    program.mutableComments = [NSMutableArray array];
    program.decimalWheel = -1;

    NSArray<NSString *> *rawLines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSUInteger lineNumber = 0;
    for (NSString *rawLine in rawLines) {
        lineNumber++;
        NSString *line = rawLine;
        if ([line hasSuffix:@"\r"]) line = [line substringToIndex:line.length - 1];
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        trimmed = [trimmed stringByTrimmingCharactersInSet:[NSCharacterSet controlCharacterSet]];
        if (trimmed.length == 0) continue;

        if ([trimmed hasPrefix:@"#"]) {
            [program.mutableComments addObject:line];
            NSString *comment = trimmed;

            NSArray<NSTextCheckingResult *> *wheelMatches =
                [[self wheelRegex] matchesInString:comment options:0 range:NSMakeRange(0, comment.length)];
            for (NSTextCheckingResult *match in wheelMatches) {
                NSString *value = [comment substringWithRange:[match rangeAtIndex:1]];
                NSInteger wheel = value.integerValue;
                if (wheel >= 0 && wheel <= 15) program.decimalWheel = wheel;
            }

            NSArray<NSTextCheckingResult *> *constantMatches =
                [[self constantRegex] matchesInString:comment options:0 range:NSMakeRange(0, comment.length)];
            for (NSTextCheckingResult *match in constantMatches) {
                NSString *reg = [comment substringWithRange:[match rangeAtIndex:1]];
                NSString *value = [comment substringWithRange:[match rangeAtIndex:2]];
                PCSNumber *number = [PCSNumber numberWithString:value];
                if (number) {
                    program.mutableConstants[[self canonicalRegisterKey:reg]] = number;
                }
            }
            continue;
        }

        PCS101Instruction *instruction = [PCS101Instruction instructionWithText:line];
        if (!instruction) {
            if (error) {
                *error = [NSError errorWithDomain:PCSProgramErrorDomain code:2
                                         userInfo:@{NSLocalizedDescriptionKey:
                                                        [NSString stringWithFormat:@"Invalid instruction on line %lu: “%@”",
                                                         (unsigned long)lineNumber, trimmed]}];
            }
            return nil;
        }
        [program.mutableInstructions addObject:instruction];
    }
    return program;
}

- (BOOL)appendInstructionText:(NSString *)text error:(NSError **)error {
    PCS101Instruction *instruction = [PCS101Instruction instructionWithText:text];
    if (!instruction) {
        if (error) {
            *error = [NSError errorWithDomain:PCSProgramErrorDomain code:2
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Invalid instruction: “%@”", text]}];
        }
        return NO;
    }
    [self.mutableInstructions addObject:instruction];
    return YES;
}

- (NSArray<PCS101Instruction *> *)instructions {
    return [self.mutableInstructions copy];
}

- (NSDictionary<NSString *, PCSNumber *> *)constants {
    return [self.mutableConstants copy];
}

- (NSArray<NSString *> *)commentLines {
    return [self.mutableComments copy];
}

- (NSNumber *)indexOfLabelText:(NSString *)label {
    NSUInteger index = 0;
    for (PCS101Instruction *instruction in self.mutableInstructions) {
        if ([instruction.text isEqualToString:label]) return @(index);
        index++;
    }
    return nil;
}

- (NSString *)textRepresentation {
    return [self textRepresentationWithConstants:self.mutableConstants];
}

- (NSString *)textRepresentationWithConstants:(NSDictionary<NSString *,PCSNumber *> *)constants {
    NSMutableString *out = [NSMutableString string];
    for (NSString *comment in self.mutableComments) {
        [out appendFormat:@"%@\n", comment];
    }
    if (self.decimalWheel >= 0) {
        [out appendFormat:@"# decimal wheel: %ld\n", (long)self.decimalWheel];
    }
    NSArray<NSString *> *keys = [constants.allKeys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in keys) {
        PCSNumber *number = constants[key];
        [out appendFormat:@"# constant %@ = %@\n", PCSConstantDirectiveKey(key), [number stringValue]];
    }
    for (PCS101Instruction *instruction in self.mutableInstructions) {
        [out appendFormat:@"%@\n", instruction.text];
    }
    return out;
}

- (PCS101Program *)programByMergingConstants:(NSDictionary<NSString *,PCSNumber *> *)constants {
    NSMutableDictionary<NSString *, PCSNumber *> *merged = [self.mutableConstants mutableCopy];
    for (NSString *key in constants) {
        PCSNumber *value = constants[key];
        if (value) merged[PCSConstantCanonicalKey(key)] = value;
    }
    NSString *text = [self textRepresentationWithConstants:merged];
    return [PCS101Program programWithText:text error:NULL];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<PCS101Program %lu instructions>", (unsigned long)self.mutableInstructions.count];
}

@end
