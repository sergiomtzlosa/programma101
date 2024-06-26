#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PCS101Program;
@class PCSNumber;

extern NSString *const PCSCardErrorDomain;

/// Virtual magnetic card: up to two program stripes.
@interface PCSCard : NSObject

@property (nonatomic, copy, readonly) NSArray<PCS101Program *> *stripes;

+ (instancetype)cardWithProgram:(PCS101Program *)program;
/// Records the program together with a snapshot of its numeric card constants
/// (normally the D/d, E/e and F/f registers).
+ (instancetype)cardWithProgram:(PCS101Program *)program
                      constants:(nullable NSDictionary<NSString *, PCSNumber *> *)constants;
+ (instancetype)cardWithPrograms:(NSArray<PCS101Program *> *)programs;
+ (nullable instancetype)cardWithText:(NSString *)text error:(NSError **)error;

- (nullable PCS101Program *)programForStripe:(NSInteger)stripeIndex;
- (NSString *)textRepresentation;

@end

NS_ASSUME_NONNULL_END
