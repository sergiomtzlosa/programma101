#import "PCSInstruction.h"

@implementation PCS101Instruction

+ (instancetype)instructionWithText:(NSString *)text {
    if (![text isKindOfClass:[NSString class]]) return nil;
    NSString *t = [text stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    if (t.length == 1) {
        t = [NSString stringWithFormat:@"  %@", t];
    } else if (t.length == 2) {
        unichar first = [t characterAtIndex:0];
        if (first == ' ' || (first >= 'A' && first <= 'Z') || first == '/') {
            t = [NSString stringWithFormat:@"%c %c", first, [t characterAtIndex:1]];
        }
    }
    if (t.length < 3) return nil;
    if (t.length > 3) t = [t substringToIndex:3];

    PCS101Instruction *ins = [PCS101Instruction new];
    ins->_text = [t copy];
    unichar key1 = [t characterAtIndex:0];
    unichar key2 = [t characterAtIndex:1];
    ins->_operation = [t characterAtIndex:2];

    if (key1 == ' ') {
        ins->_registerKey = (key2 == '/') ? @"/" : @"M";
    } else if (key2 == '/') {
        ins->_registerKey = [[NSString stringWithFormat:@"%c", key1] lowercaseString];
    } else {
        ins->_registerKey = [[NSString stringWithFormat:@"%c", key1] uppercaseString];
    }
    return ins;
}

- (BOOL)isJump {
    return _operation == 'V' || _operation == 'W' || _operation == 'Y' || _operation == 'Z';
}

- (BOOL)isJumpOrigin {
    if (![self isJump]) return NO;
    unichar key1 = [_text characterAtIndex:0];
    unichar key2 = [_text characterAtIndex:1];
    BOOL originRegister = (key1 == ' ' || key1 == 'C' || key1 == 'D' || key1 == 'R');
    return originRegister && (key2 == ' ' || key2 == '/');
}

- (BOOL)isConditionalJump {
    return [self isJumpOrigin] && [_text characterAtIndex:1] == '/';
}

- (BOOL)isLabel {
    return [self isJump] && ![self isJumpOrigin];
}

- (BOOL)isConstantLoader {
    return [_text isEqualToString:@"A/^"];
}

- (NSString *)jumpTargetText {
    if (![self isJumpOrigin]) return nil;
    unichar key1 = [_text characterAtIndex:0];
    unichar targetRegister;
    switch (key1) {
        case ' ': targetRegister = 'A'; break;
        case 'C': targetRegister = 'B'; break;
        case 'D': targetRegister = 'E'; break;
        case 'R': targetRegister = 'F'; break;
        default: return nil;
    }
    return [NSString stringWithFormat:@"%c%c%c", targetRegister, [_text characterAtIndex:1], _operation];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@>", _text];
}

@end
