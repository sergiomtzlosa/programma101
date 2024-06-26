#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// One Programma 101 instruction, stored in the three-character listing notation:
///   [register or space][space or '/'][operator]
/// Examples: "B +", "B/$", "  S", " /V", "A/V", "A/^".
@interface PCS101Instruction : NSObject

@property (nonatomic, copy, readonly) NSString *text;        // exactly 3 characters
@property (nonatomic, copy, readonly) NSString *registerKey; // "M", "A"…"F", "b"…"f", "/"
@property (nonatomic, assign, readonly) unichar operation;

+ (nullable instancetype)instructionWithText:(NSString *)text;

- (BOOL)isJump;             // any V/W/Y/Z instruction
- (BOOL)isJumpOrigin;       // executable jump (not a label)
- (BOOL)isConditionalJump;  // origin with a '/' register modifier
- (BOOL)isLabel;            // reference point line, e.g. "A V" or "A/V"
- (BOOL)isConstantLoader;   // the special "A/^" sequence prefix
- (nullable NSString *)jumpTargetText;

@end

NS_ASSUME_NONNULL_END
