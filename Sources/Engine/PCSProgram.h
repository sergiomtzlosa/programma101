#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PCSNumber;
@class PCS101Instruction;

extern NSString *const PCSProgramErrorDomain;

@interface PCS101Program : NSObject

@property (nonatomic, copy, readonly) NSArray<PCS101Instruction *> *instructions;
/// Card constants keyed by register ("D", "E", "F", "d", …).
@property (nonatomic, copy, readonly) NSDictionary<NSString *, PCSNumber *> *constants;
/// Decimal wheel declared by the listing, or -1 when unspecified.
@property (nonatomic, assign, readonly) NSInteger decimalWheel;
@property (nonatomic, copy, readonly) NSArray<NSString *> *commentLines;

+ (nullable instancetype)programWithText:(NSString *)text error:(NSError **)error;
- (BOOL)appendInstructionText:(NSString *)text error:(NSError **)error;

- (nullable NSNumber *)indexOfLabelText:(NSString *)label;
- (NSString *)textRepresentation;
/// Returns a copy whose card-constant directives include/override `constants`.
- (nullable PCS101Program *)programByMergingConstants:(NSDictionary<NSString *, PCSNumber *> *)constants;

@end

NS_ASSUME_NONNULL_END
